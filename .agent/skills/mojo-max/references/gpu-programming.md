# GPU Programming Fundamentals

## Table of Contents
- [GPU Programming Model](#gpu-programming-model)
- [DeviceContext](#devicecontext)
- [Memory Management](#memory-management)
- [Kernel Functions](#kernel-functions)
- [Grid and Thread Organization](#grid-and-thread-organization)
- [Complete Example](#complete-example)

## GPU Programming Model

GPU programming follows a host-device pattern:

1. **Host (CPU)**: Manages program flow, allocates memory, launches kernels
2. **Device (GPU)**: Executes parallel computations across thousands of threads

### Typical Workflow
```
1. Initialize data on host (CPU)
2. Allocate device (GPU) memory
3. Copy data: host → device
4. Launch kernel function on GPU
5. Copy results: device → host
6. Free device memory
```

## DeviceContext

`DeviceContext` is the main interface for GPU operations.

### Check for GPU
```mojo
from sys import has_accelerator, has_nvidia_gpu_accelerator, has_amd_gpu_accelerator

@parameter
if has_accelerator():
    print("GPU available")
elif has_nvidia_gpu_accelerator():
    print("NVIDIA GPU")
elif has_amd_gpu_accelerator():
    print("AMD GPU")
else:
    print("No GPU")
```

### Create DeviceContext
```mojo
from gpu.host import DeviceContext

fn main() raises:
    # Default GPU (device 0)
    var ctx = DeviceContext()
    
    # Specific device
    var ctx1 = DeviceContext(device_id=1)
    
    # Specific vendor
    var nvidia_ctx = DeviceContext(api="cuda")
    var amd_ctx = DeviceContext(api="hip")
    var apple_ctx = DeviceContext(api="metal")
    
    # Query number of devices
    var num_gpus = DeviceContext.number_of_devices()
```

### Asynchronous Operations
Most operations are asynchronous. Use `synchronize()` to wait.

```mojo
ctx.enqueue_create_buffer[DType.float32](1024)  # Async
ctx.enqueue_copy(src_buf=host, dst_buf=device)  # Async
ctx.enqueue_function[kernel, kernel](...)       # Async

ctx.synchronize()  # Wait for all operations to complete
```

## Memory Management

### HostBuffer (CPU Memory)
```mojo
# Create host buffer
var host_buf = ctx.enqueue_create_host_buffer[DType.float32](size)
ctx.synchronize()  # Wait before writing

# Initialize data
for i in range(size):
    host_buf[i] = Float32(i)

# Access raw pointer
var ptr = host_buf.unsafe_ptr()
```

### DeviceBuffer (GPU Memory)
```mojo
# Create device buffer
var device_buf = ctx.enqueue_create_buffer[DType.float32](size)

# DeviceBuffer passes to kernels as UnsafePointer
# Cannot access elements directly from host
```

### Copy Operations
```mojo
# Host → Device
ctx.enqueue_copy(src_buf=host_buf, dst_buf=device_buf)

# Device → Host
ctx.enqueue_copy(src_buf=device_buf, dst_buf=host_buf)

# Alternative syntax
host_buf.enqueue_copy_to(dst=device_buf)
device_buf.enqueue_copy_to(dst=host_buf)
```

### Convenience: map_to_host
For testing/debugging (not production - involves copies):

```mojo
with device_buf.map_to_host() as host_view:
    for i in range(size):
        host_view[i] = Float32(i)
    # Changes automatically copied back to device
```

## Kernel Functions

### Requirements
- Must use `fn` (not `def`)
- Must NOT use `raises`
- Cannot return values (use output buffers)
- Arguments must be `DevicePassable`

### Basic Kernel
```mojo
from gpu import block_idx, thread_idx, block_dim, global_idx

fn my_kernel(
    output: UnsafePointer[Float32, MutAnyOrigin],
    input: UnsafePointer[Float32, MutAnyOrigin],
    size: Int
):
    var idx = global_idx.x
    if idx < size:  # Bounds check!
        output[idx] = input[idx] * 2.0
```

### Compile and Launch
```mojo
# Compile kernel
var compiled = ctx.compile_function[my_kernel, my_kernel]()

# Launch with explicit kernel object
ctx.enqueue_function(
    compiled,
    output_buf,
    input_buf,
    size,
    grid_dim=(num_blocks,),
    block_dim=(threads_per_block,)
)

# Or compile and launch in one step
ctx.enqueue_function[my_kernel, my_kernel](
    output_buf,
    input_buf,
    size,
    grid_dim=(num_blocks,),
    block_dim=(threads_per_block,)
)
```

### DevicePassable Types

| Host Type | Device Type (in kernel) |
|-----------|------------------------|
| `Int` | `Int` |
| `Float32` | `Float32` |
| `SIMD[dtype, width]` | `SIMD[dtype, width]` |
| `DeviceBuffer[dtype]` | `UnsafePointer[SIMD[dtype, 1]]` |
| `LayoutTensor` | `LayoutTensor` |

## Grid and Thread Organization

### Hierarchy
```
Grid
├── Block (0,0)
│   ├── Thread (0,0)
│   ├── Thread (1,0)
│   └── ...
├── Block (1,0)
│   └── ...
└── ...
```

### Dimensions (up to 3D)
```mojo
# 1D
grid_dim=64               # 64 blocks
block_dim=256             # 256 threads per block

# 2D
grid_dim=(8, 8)           # 8x8 blocks
block_dim=(16, 16)        # 16x16 threads per block

# 3D
grid_dim=(4, 4, 4)        # 4x4x4 blocks
block_dim=(8, 8, 4)       # 8x8x4 threads per block
```

### Thread Indexing
```mojo
from gpu import block_dim, block_idx, thread_idx, global_idx, grid_dim

fn kernel():
    # Grid dimensions
    var gx = grid_dim.x      # Number of blocks in x
    var gy = grid_dim.y      # Number of blocks in y
    
    # Block dimensions
    var bx = block_dim.x     # Threads per block in x
    var by = block_dim.y     # Threads per block in y
    
    # Block index (which block)
    var bi = block_idx.x
    var bj = block_idx.y
    
    # Thread index (within block)
    var ti = thread_idx.x
    var tj = thread_idx.y
    
    # Global index (convenient shorthand)
    var gi = global_idx.x    # = block_dim.x * block_idx.x + thread_idx.x
    var gj = global_idx.y
```

### Calculating Grid Size
```mojo
fn calculate_grid(total_elements: Int, threads_per_block: Int) -> Int:
    return (total_elements + threads_per_block - 1) // threads_per_block

# Example: 10000 elements, 256 threads per block
var num_blocks = calculate_grid(10000, 256)  # = 40 blocks
```

### Bounds Checking
Essential when total threads > data size:

```mojo
fn safe_kernel(data: UnsafePointer[Float32, MutAnyOrigin], size: Int):
    var idx = global_idx.x
    if idx < size:  # Prevent out-of-bounds access
        data[idx] *= 2.0
```

## Complete Example

```mojo
from sys import has_accelerator
from gpu.host import DeviceContext
from gpu import global_idx

alias NUM_ELEMENTS = 1024
alias BLOCK_SIZE = 256

fn vector_add(
    out: UnsafePointer[Float32, MutAnyOrigin],
    a: UnsafePointer[Float32, MutAnyOrigin],
    b: UnsafePointer[Float32, MutAnyOrigin],
    size: Int
):
    var idx = global_idx.x
    if idx < size:
        out[idx] = a[idx] + b[idx]

def main():
    @parameter
    if not has_accelerator():
        print("No GPU available")
        return
    
    # Initialize context
    var ctx = DeviceContext()
    
    # Create host buffers
    var host_a = ctx.enqueue_create_host_buffer[DType.float32](NUM_ELEMENTS)
    var host_b = ctx.enqueue_create_host_buffer[DType.float32](NUM_ELEMENTS)
    var host_out = ctx.enqueue_create_host_buffer[DType.float32](NUM_ELEMENTS)
    ctx.synchronize()
    
    # Initialize input data
    for i in range(NUM_ELEMENTS):
        host_a[i] = Float32(i)
        host_b[i] = Float32(i * 2)
    
    # Create device buffers
    var dev_a = ctx.enqueue_create_buffer[DType.float32](NUM_ELEMENTS)
    var dev_b = ctx.enqueue_create_buffer[DType.float32](NUM_ELEMENTS)
    var dev_out = ctx.enqueue_create_buffer[DType.float32](NUM_ELEMENTS)
    
    # Copy to device
    ctx.enqueue_copy(src_buf=host_a, dst_buf=dev_a)
    ctx.enqueue_copy(src_buf=host_b, dst_buf=dev_b)
    
    # Calculate grid dimensions
    var num_blocks = (NUM_ELEMENTS + BLOCK_SIZE - 1) // BLOCK_SIZE
    
    # Launch kernel
    ctx.enqueue_function[vector_add, vector_add](
        dev_out, dev_a, dev_b, NUM_ELEMENTS,
        grid_dim=(num_blocks,),
        block_dim=(BLOCK_SIZE,)
    )
    
    # Copy results back
    ctx.enqueue_copy(src_buf=dev_out, dst_buf=host_out)
    ctx.synchronize()
    
    # Verify
    print("Result[0]:", host_out[0])    # 0
    print("Result[100]:", host_out[100]) # 100 + 200 = 300
```

## Tips

1. **Always bounds check** in kernels - grid may have more threads than data

2. **Use appropriate block sizes** - typically 128, 256, or 512 threads

3. **Minimize host-device copies** - they're expensive

4. **Batch operations** before calling `synchronize()`

5. **Use `@parameter if has_accelerator()`** for compile-time GPU detection
