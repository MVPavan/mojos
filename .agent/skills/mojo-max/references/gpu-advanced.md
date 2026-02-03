# Advanced GPU Programming

## Table of Contents
- [LayoutTensor](#layouttensor)
- [Shared Memory](#shared-memory)
- [Synchronization](#synchronization)
- [Warp Operations](#warp-operations)
- [Tensor Cores](#tensor-cores)
- [Memory Hierarchy](#memory-hierarchy)

## LayoutTensor

`LayoutTensor` provides high-performance tensor operations with explicit memory layouts.

### Creating LayoutTensor
```mojo
from layout import Layout, LayoutTensor

# Define layout
alias layout_2d = Layout.row_major(16, 16)  # 16x16 row-major

# Create from pointer (GPU global memory)
fn kernel(data: UnsafePointer[Float32, MutAnyOrigin]):
    var tensor = LayoutTensor[DType.float32, layout_2d](data)
    
    # Access elements
    var val = tensor[row, col]
    tensor[row, col] = new_val
```

### Tiling for Cache Efficiency
```mojo
fn tiled_kernel[
    BM: Int,  # Block rows
    BN: Int,  # Block cols
](
    A: LayoutTensor[DType.float32, layout_a, MutableAnyOrigin],
    B: LayoutTensor[DType.float32, layout_b, MutableAnyOrigin],
    C: LayoutTensor[DType.float32, layout_c, MutableAnyOrigin],
):
    # Extract tile for this block
    var block_row = block_idx.y * BM
    var block_col = block_idx.x * BN
    
    var A_tile = A.tile[BM, BK](block_row, 0)
    var B_tile = B.tile[BK, BN](0, block_col)
    var C_tile = C.tile[BM, BN](block_row, block_col)
```

### Vectorized Access
```mojo
# Create vectorized view (4 elements per access)
var vec_tensor = tensor.vectorize[4]()

# Load/store 4 elements at once
var vec = tensor.load[width=4](row, col)
tensor.store[width=4](row, col, vec)
```

### Thread Distribution
```mojo
# Distribute tensor across threads in block
alias thread_layout = Layout.row_major(16, 16)
var fragment = tensor.distribute[thread_layout](thread_idx.x)
```

## Shared Memory

Shared memory is fast, block-local memory for thread cooperation.

### Allocating Shared Memory
```mojo
from memory import stack_allocation
from gpu import AddressSpace

fn kernel_with_shared():
    # Allocate in shared memory
    var shared = stack_allocation[
        256,  # Number of elements
        DType.float32,
        address_space = AddressSpace.SHARED
    ]()
    
    # Use as tensor
    alias shared_layout = Layout.row_major(16, 16)
    var shared_tensor = LayoutTensor[
        DType.float32, 
        shared_layout,
        address_space = AddressSpace.SHARED
    ](shared)
```

### Copy Patterns
```mojo
from layout.layout_tensor import copy_dram_to_sram, copy_sram_to_dram

fn tiled_kernel(
    global_data: LayoutTensor[DType.float32, layout, MutableAnyOrigin]
):
    # Allocate shared memory tile
    var shared_tile = stack_allocation[
        TILE_SIZE * TILE_SIZE,
        DType.float32,
        address_space = AddressSpace.SHARED
    ]()
    
    # Copy from global to shared
    copy_dram_to_sram(
        dst=shared_tile_tensor,
        src=global_data.tile[TILE_M, TILE_N](block_row, block_col)
    )
    
    barrier()  # Sync before using shared data
    
    # ... compute using shared memory ...
    
    barrier()  # Sync before writing back
    
    # Copy from shared to global
    copy_sram_to_dram(
        dst=global_data.tile[TILE_M, TILE_N](block_row, block_col),
        src=shared_tile_tensor
    )
```

## Synchronization

### Block-Level Barrier
```mojo
from gpu.sync import barrier

fn kernel_with_barrier():
    # Phase 1: All threads write to shared memory
    shared[thread_idx.x] = compute_value()
    
    barrier()  # Wait for ALL threads in block
    
    # Phase 2: Read neighbor's data (safe now)
    var neighbor = shared[(thread_idx.x + 1) % block_dim.x]
```

### Double-Barrier Pattern (Producer-Consumer)
```mojo
fn iterative_kernel():
    for iteration in range(num_iterations):
        # Load from global to shared
        shared[tid] = global_data[global_idx]
        
        barrier()  # Ensure loads complete before computation
        
        # Compute using shared data
        var result = compute(shared)
        
        barrier()  # Ensure computation complete before next load
```

### Warp Synchronization
```mojo
from gpu.sync import syncwarp

fn warp_level_kernel():
    # Warp-level computation
    var warp_result = warp_reduce(value)
    
    syncwarp()  # Sync threads within warp
    
    # Continue with synchronized warp
```

### Named Barriers (NVIDIA only)
```mojo
from gpu.sync import named_barrier

fn multi_phase_kernel():
    # Different thread subsets can use different barriers
    named_barrier(barrier_id=0, num_threads=128)
```

## Warp Operations

Warps are groups of threads (32 on NVIDIA, 64 on AMD) executing in lockstep.

### Warp Shuffle
```mojo
from gpu.warp import shuffle_down, shuffle_up, shuffle_xor

fn warp_reduction(value: Float32) -> Float32:
    var result = value
    
    # Reduce across warp using shuffle
    result += shuffle_down(result, 16)
    result += shuffle_down(result, 8)
    result += shuffle_down(result, 4)
    result += shuffle_down(result, 2)
    result += shuffle_down(result, 1)
    
    return result  # Lane 0 has final sum
```

### Warp Vote
```mojo
from gpu.warp import ballot, any_sync, all_sync

fn check_condition(cond: Bool):
    # Check if ANY thread has condition
    if any_sync(cond):
        handle_any_true()
    
    # Check if ALL threads have condition
    if all_sync(cond):
        handle_all_true()
    
    # Get bitmask of which threads have condition
    var mask = ballot(cond)
```

### Lane ID
```mojo
from gpu import lane_id

fn per_lane_kernel():
    var my_lane = lane_id()  # 0-31 (or 0-63 on AMD)
    
    if my_lane == 0:
        # First lane in warp does special work
        pass
```

## Tensor Cores

Tensor Cores are specialized hardware for matrix multiply-accumulate (MMA).

### Basic Usage
```mojo
from layout.tensor_core import TensorCore

fn matmul_kernel[
    M: Int, N: Int, K: Int,
    MMA_M: Int, MMA_N: Int, MMA_K: Int,
](
    A: LayoutTensor[DType.float16, layout_a, MutableAnyOrigin],
    B: LayoutTensor[DType.float16, layout_b, MutableAnyOrigin],
    C: LayoutTensor[DType.float32, layout_c, MutableAnyOrigin],
):
    # Initialize tensor core
    var tc = TensorCore[
        out_type = DType.float32,
        in_type = DType.float16,
        shape = (MMA_M, MMA_N, MMA_K)
    ]()
    
    # Load matrix fragments
    var a_frag = tc.load_a(A_tile)
    var b_frag = tc.load_b(B_tile)
    var c_frag = tc.load_c(C_tile)
    
    # Matrix multiply-accumulate
    c_frag = tc.mma(a_frag, b_frag, c_frag)
    
    # Store result
    tc.store_c(C_tile, c_frag)
```

### Supported Shapes
Common MMA shapes (varies by GPU):
- NVIDIA: 16x16x16, 8x8x4, 16x8x16
- AMD: 16x16x16, 32x32x8

```mojo
# Query supported shapes
var shapes = TensorCore.get_shapes[DType.float32, DType.float16]()
```

## Memory Hierarchy

### GPU Memory Spaces

| Memory | Scope | Latency | Size |
|--------|-------|---------|------|
| Registers | Thread | ~1 cycle | KB per thread |
| Shared | Block | ~30 cycles | ~48-164 KB |
| L1 Cache | SM | ~30 cycles | ~128 KB |
| L2 Cache | Device | ~200 cycles | MB |
| Global (HBM) | Device | ~400 cycles | GB |

### Optimal Access Patterns

**Coalesced Global Memory Access:**
```mojo
# GOOD: Adjacent threads access adjacent memory
fn coalesced(data: UnsafePointer[Float32, MutAnyOrigin]):
    var idx = global_idx.x
    var val = data[idx]  # Coalesced

# BAD: Strided access
fn strided(data: UnsafePointer[Float32, MutAnyOrigin], stride: Int):
    var idx = global_idx.x * stride  # Non-coalesced
    var val = data[idx]
```

**Shared Memory Bank Conflicts:**
```mojo
# Shared memory has 32 banks (4 bytes each)
# Avoid multiple threads accessing same bank

# GOOD: Each thread accesses different bank
shared[thread_idx.x] = value

# BAD: All threads access same bank (32-way conflict)
shared[thread_idx.x * 32] = value
```

### Async Memory Operations
```mojo
from gpu.memory import async_copy

fn async_kernel():
    # Initiate async copy from global to shared
    async_copy(dst=shared_ptr, src=global_ptr, size=bytes)
    
    # Do other work while copy in progress...
    
    # Wait for copy to complete
    async_copy_wait()
```

## Performance Tips

1. **Maximize occupancy** - Use enough threads to hide latency

2. **Coalesce memory access** - Adjacent threads should access adjacent memory

3. **Use shared memory** - Cache frequently accessed data

4. **Avoid warp divergence** - Keep branches consistent within warps

5. **Use Tensor Cores** - For matrix operations, 10x+ speedup possible

6. **Double buffer** - Overlap computation with memory transfers

7. **Minimize synchronization** - Each barrier has overhead
