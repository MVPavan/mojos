from gpu import thread_idx, block_idx, block_dim, barrier
from gpu.host import DeviceContext
from layout import Layout, LayoutTensor
from layout.tensor_builder import LayoutTensorBuild as tb
from sys import sizeof, argv
from testing import assert_equal

alias dtype = DType.float32
alias TPB = 8
alias SIZE_2 = 15
alias CONV_2 = 4
alias BLOCKS_PER_GRID_2 = (3, 1)
alias THREADS_PER_BLOCK_2 = (TPB, 1)
alias in_2_layout = Layout.row_major(SIZE_2)
alias out_2_layout = Layout.row_major(SIZE_2)
alias conv_2_layout = Layout.row_major(CONV_2)
alias full_out_layout = Layout.row_major(SIZE_2+CONV_2-1)


# ANCHOR: conv_1d_block_boundary_solution
fn conv_1d_block_boundary[
    in_layout: Layout, out_layout: Layout, conv_layout: Layout, dtype: DType
](
    output: LayoutTensor[mut=False, dtype, out_layout],
    a: LayoutTensor[mut=False, dtype, in_layout],
    b: LayoutTensor[mut=False, dtype, conv_layout],
):
    global_i = block_dim.x * block_idx.x + thread_idx.x
    local_i = thread_idx.x
    # first: need to account for padding
    shared_a = tb[dtype]().row_major[TPB + CONV_2 - 1]().shared().alloc()
    shared_b = tb[dtype]().row_major[CONV_2]().shared().alloc()
    if global_i < SIZE_2:
        shared_a[local_i] = a[global_i]
    else:
        shared_a[local_i] = 0

    # second: load elements needed for convolution at block boundary
    if local_i < CONV_2 - 1:
        # indices from next block
        next_idx = global_i + TPB
        if next_idx < SIZE_2:
            shared_a[TPB + local_i] = a[next_idx]
        else:
            # Initialize out-of-bounds elements to 0 to avoid reading from uninitialized memory
            # which is an undefined behavior
            shared_a[TPB + local_i] = 0

    if local_i < CONV_2:
        shared_b[local_i] = b[local_i]

    barrier()

    if global_i < SIZE_2:
        var local_sum: output.element_type = 0

        @parameter
        for j in range(CONV_2):
            if global_i + j < SIZE_2:
                local_sum += shared_a[local_i + j] * shared_b[j]

        output[global_i] = local_sum


# ANCHOR: conv_1d_block_boundary_solution
fn conv_1d_full[
    in_layout: Layout, out_layout: Layout, conv_layout: Layout, dtype: DType
](
    output: LayoutTensor[mut=False, dtype, out_layout],
    a: LayoutTensor[mut=False, dtype, in_layout],
    b: LayoutTensor[mut=False, dtype, conv_layout],
):
    global_i = block_dim.x * block_idx.x + thread_idx.x
    local_i = thread_idx.x
    # first: need to account for padding

    shared_a = tb[dtype]().row_major[TPB + CONV_2 - 1]().shared().alloc()
    shared_b = tb[dtype]().row_major[CONV_2]().shared().alloc()

    if global_i < CONV_2 - 1:
        shared_a[local_i] = 0
    elif CONV_2-1 <= global_i < SIZE_2 + CONV_2-1:
        shared_a[local_i] = a[global_i - (CONV_2 - 1)]
    else:
        shared_a[local_i] = 0
    
    if local_i < CONV_2 - 1:
        # indices from next block
        next_idx = global_i + TPB
        if CONV_2-1 <= next_idx < SIZE_2 + CONV_2-1:
            shared_a[TPB + local_i] = a[next_idx - (CONV_2 - 1)]
        else:
            shared_a[TPB + local_i] = 0
    

    if local_i < CONV_2:
        shared_b[local_i] = b[local_i]
    else:
        shared_b[local_i] = 0
    
    barrier()

    if global_i < SIZE_2 + CONV_2 - 1:
        var local_sum: output.element_type = 0

        @parameter
        for j in range(CONV_2):
            if global_i + j < SIZE_2 + CONV_2 - 1:
                local_sum += shared_a[local_i + j] * shared_b[j]

        output[global_i] = local_sum


# ANCHOR_END: conv_1d_block_boundary_solution

def main():
    with DeviceContext() as ctx:
        size = SIZE_2
        conv = CONV_2
        out = ctx.enqueue_create_buffer[dtype](size).enqueue_fill(0)
        full_out = ctx.enqueue_create_buffer[dtype](size+conv-1).enqueue_fill(0)
        a = ctx.enqueue_create_buffer[dtype](size).enqueue_fill(0)
        b = ctx.enqueue_create_buffer[dtype](conv).enqueue_fill(0)
        
        with a.map_to_host() as a_host:
            for i in range(size):
                a_host[i] = i

        with b.map_to_host() as b_host:
            for i in range(conv):
                b_host[i] = i
        
        expected = ctx.enqueue_create_host_buffer[dtype](size).enqueue_fill(0)
        with a.map_to_host() as a_host, b.map_to_host() as b_host:
            for i in range(size):
                for j in range(conv):
                    if i + j < size:
                        expected[i] += a_host[i + j] * b_host[j]
            print("array a:", a_host)
            print("Conv:", b_host)
            print("expected:", expected)

        var out_tensor = LayoutTensor[mut=False, dtype, out_2_layout](
            out.unsafe_ptr()
        )
        var full_out_tensor = LayoutTensor[mut=False, dtype, full_out_layout](
            full_out.unsafe_ptr()
        )
        var a_tensor = LayoutTensor[mut=False, dtype, in_2_layout](
            a.unsafe_ptr()
        )
        var b_tensor = LayoutTensor[mut=False, dtype, conv_2_layout](
            b.unsafe_ptr()
        )
        ctx.enqueue_function[
            conv_1d_block_boundary[
                in_2_layout, out_2_layout, conv_2_layout, dtype
            ]
        ](
            out_tensor,
            a_tensor,
            b_tensor,
            grid_dim=BLOCKS_PER_GRID_2,
            block_dim=THREADS_PER_BLOCK_2,
        )
        ctx.enqueue_function[
            conv_1d_full[
                in_2_layout, full_out_layout, conv_2_layout, dtype
            ]
        ](
            full_out_tensor,
            a_tensor,
            b_tensor,
            grid_dim=BLOCKS_PER_GRID_2,
            block_dim=THREADS_PER_BLOCK_2,
        )
        ctx.synchronize()
        with out.map_to_host() as out_host:
            print("out:", out_host)
            for i in range(size):
                assert_equal(out_host[i], expected[i])
        with full_out.map_to_host() as full_out_host:
            print("full_out:", full_out_host)
