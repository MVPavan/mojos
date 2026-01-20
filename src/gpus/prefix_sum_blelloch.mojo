# prefix sum using Blelloch scan algorithm

from gpu import thread_idx, block_idx, block_dim, barrier
from gpu.host import DeviceContext
from layout import Layout, LayoutTensor
from layout.tensor_builder import LayoutTensorBuild as tb
from sys import sizeof, argv
from math import log2
from testing import assert_equal
import benchmark
from benchmark import Unit

# alias TPB = 8
alias dtype = DType.float32


fn blelloch_up_sweep[
    layout: Layout, TPB: Int
](
    output: LayoutTensor[mut=False, dtype, layout],
    a: LayoutTensor[mut=False, dtype, layout],
    size: Int,
    out_size: Int,
):
    global_i = block_dim.x * block_idx.x + thread_idx.x
    local_i = thread_idx.x
    shared = tb[dtype]().row_major[TPB]().shared().alloc()
    
    if global_i < size:
        shared[local_i] = a[global_i]
    else:
        shared[local_i] = 0

    barrier()

    offset = 1
    for i in range(Int(log2(Scalar[dtype](TPB)))):
        ai = 2**(i+1)
        bi = 2**i
        if local_i % ai==0 and local_i + ai - 1 < TPB:
            shared[local_i + ai - 1] += shared[local_i + bi - 1]
        barrier()
        offset *= 2

    if global_i < out_size:
        output[global_i] = shared[local_i]


fn blelloch_down_sweep[
    layout: Layout, TPB: Int
](
    output: LayoutTensor[mut=False, dtype, layout],
    a: LayoutTensor[mut=False, dtype, layout],
    size: Int,
    out_size: Int,
):
    global_i = block_dim.x * block_idx.x + thread_idx.x
    local_i = thread_idx.x
    shared = tb[dtype]().row_major[TPB]().shared().alloc()
    
    var block_offset:output.element_type = 0
    for blk in range(block_idx.x):
        block_offset += a[(blk+1) * TPB - 1]  # accumulate block sums

    if global_i < out_size:
        shared[local_i] = a[global_i]
    else:
        shared[local_i] = 0

    if local_i == TPB - 1:
        shared[local_i] = 0  # set last element to zero
    
    barrier()

    offset = 1
    for i in reversed(range(Int(log2(Scalar[dtype](TPB))))):
        ai = 2**(i+1)
        bi = 2**i
        if local_i % ai == 0 and local_i + ai - 1 < TPB:
            temp = shared[local_i + bi - 1]
            shared[local_i + bi - 1] = shared[local_i + ai - 1]
            shared[local_i + ai - 1] += temp
        barrier()
        offset *= 2

    if global_i <= size:
        if local_i > 0:
            output[global_i-1] = shared[local_i]+block_offset  # first element is zero
        if global_i < size and local_i == TPB - 1:
            output[global_i] = a[global_i]+block_offset  # first element is zero
    else:
        output[global_i] = -1  # out of bounds, set to zero
    

def launch_kernels[size:Int, layout: Layout, TPB: Int = 8](verify: Bool = True):
    '''
    Launch the Blelloch prefix sum kernels with the specified size and layout.
    '''
    # TPB must be a power of 2
    if TPB & (TPB - 1) != 0:
        raise "TPB must be a power of 2"
    if TPB < 1 or TPB > 1024:
        raise "TPB must be between 1 and 1024"
    BPG = min(size // TPB + (1 if size % TPB != 0 else 0), 512)
    if verify:
        print("\nLaunching kernels: ", "Array size:", size, ", TPB:", TPB, ", BPG:", BPG, "\n")

    size_offset = (TPB - size % TPB) % TPB
    out_size = size +  size_offset # round up to nearest multiple of TPB
    
    with DeviceContext() as ctx:
        a = ctx.enqueue_create_buffer[dtype](size).enqueue_fill(0)
        output = ctx.enqueue_create_buffer[dtype](out_size).enqueue_fill(0)
        
        with a.map_to_host() as a_host:
            for i in range(size):
                a_host[i] = i + 1  # Fill with 1, 2, ..., size
        
        a_tensor = LayoutTensor[mut=False, dtype, layout](a.unsafe_ptr())
        output_tensor = LayoutTensor[mut=False, dtype, layout](output.unsafe_ptr())
                
        ctx.enqueue_function[blelloch_up_sweep[layout, TPB]](
            output_tensor,
            a_tensor,
            size,
            out_size,
            grid_dim=(BPG, 1),
            block_dim=(TPB, 1),
        )

        ctx.enqueue_function[blelloch_down_sweep[layout, TPB]](
            output_tensor,
            output_tensor,
            size,
            out_size,
            grid_dim=(BPG, 1),
            block_dim=(TPB, 1),
        )
        ctx.synchronize()
        
        if verify:
            expected = ctx.enqueue_create_host_buffer[dtype](size).enqueue_fill(0)
            with a.map_to_host() as a_host:
                expected[0] = a_host[0]
                for i in range(1, size):
                    expected[i] = expected[i-1] + a_host[i]
            
            if size<=64:
                with output.map_to_host() as out_host, a.map_to_host() as a_host:
                    print("input:", a_host)
                    print("expected:", expected)
                    print("final output:", out_host)

            with output.map_to_host() as out_host:
                for i in range(size):
                    assert_equal(
                        out_host[i], expected[i], 
                        "Mismatch at index {}: expected {}, got {}".format(i, expected[i], out_host[i])  
                    )
                print("All results match expected values.")


def test_prefix_sum():
    print("Launching prefix sum kernels with different sizes and configurations:")
    # TBP = 8
    print("\n size = 1 < TPB :")
    launch_kernels[1, Layout.row_major(1)]()

    print("\n size = 5 < TPB :")
    launch_kernels[5, Layout.row_major(5)]()

    print("\n size = 7 < TPB :")
    launch_kernels[7, Layout.row_major(7)]()

    print("\n size = TPB :")
    launch_kernels[8, Layout.row_major(8)]()

    print("\n size = 9 > TPB :")
    launch_kernels[9, Layout.row_major(9)]()
    
    print("\n size = 12 > TPB :")
    launch_kernels[12, Layout.row_major(12)]()
    
    print("\n size = 15 > TPB :")
    launch_kernels[15, Layout.row_major(15)]()

    print("\n size = 2 * TPB :")
    launch_kernels[16, Layout.row_major(16)]()

    print("\n size = 17 > 2 * TPB :")
    launch_kernels[17, Layout.row_major(17)]()
    
    print("\n size = 20 > 2 * TPB :")
    launch_kernels[20, Layout.row_major(20)]()
    
    print("\n size = 23 > 2 * TPB :")
    launch_kernels[23, Layout.row_major(23)]()
    
    print("\n size = 3 * TPB :")
    launch_kernels[24, Layout.row_major(24)]()

def benchmark_kernel():
    alias TPB = 128
    alias size = 5000
    launch_kernels[size, Layout.row_major(size), TPB](verify=False)


def main():
    # test_prefix_sum()
    alias TPB = 128
    alias size = 5000
    # launch_kernels[size, Layout.row_major(size), TPB]()

    var report = benchmark.run[benchmark_kernel]()
    report.print(Unit.ms)