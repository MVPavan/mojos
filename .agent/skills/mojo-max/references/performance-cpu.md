# CPU Performance: SIMD, Parallelism, and Compile-Time

## Table of Contents
- [SIMD Fundamentals](#simd-fundamentals)
- [The vectorize Function](#the-vectorize-function)
- [Parallelism with parallelize](#parallelism-with-parallelize)
- [Compile-Time Metaprogramming](#compile-time-metaprogramming)
- [Performance Patterns](#performance-patterns)
- [Optimization Checklist](#optimization-checklist)

## SIMD Fundamentals

SIMD (Single Instruction, Multiple Data) processes multiple values simultaneously using hardware vector registers.

### SIMD Type Basics
```mojo
# Scalar is just SIMD with width 1
var scalar: Float32 = 1.0  # Same as SIMD[DType.float32, 1]

# Create vectors
var v4 = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
var v8 = SIMD[DType.int32, 8](1, 2, 3, 4, 5, 6, 7, 8)

# Broadcast single value
var ones = SIMD[DType.float32, 8](1.0)  # [1, 1, 1, 1, 1, 1, 1, 1]
```

### Element-wise Operations
```mojo
var a = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
var b = SIMD[DType.float32, 4](4.0, 3.0, 2.0, 1.0)

var sum = a + b          # [5, 5, 5, 5]
var product = a * b      # [4, 6, 6, 4]
var squared = a * a      # [1, 4, 9, 16]

# Fused multiply-add (single instruction)
var fma = a.fused_multiply_add(b, 2.0)  # (a * b) + 2
```

### Reductions
```mojo
var v = SIMD[DType.int32, 8](1, 2, 3, 4, 5, 6, 7, 8)

var total = v.reduce_add()     # 36 (sum all)
var maximum = v.reduce_max()   # 8
var minimum = v.reduce_min()   # 1
```

### Loading and Storing
```mojo
fn process_array(ptr: UnsafePointer[Float32], size: Int):
    alias width = 8
    for i in range(0, size, width):
        # Load 8 values
        var vec = ptr.load[width=width](i)
        # Process
        vec = vec * 2.0
        # Store back
        ptr.store[width=width](i, vec)
```

### Query Hardware SIMD Width
```mojo
from sys import simdwidthof

alias float32_width = simdwidthof[DType.float32]()  # e.g., 8 on AVX2
alias float64_width = simdwidthof[DType.float64]()  # e.g., 4 on AVX2
```

## The vectorize Function

`vectorize` automatically handles SIMD processing including remainder elements.

### Basic Usage
```mojo
from algorithm.functional import vectorize
from sys import simdwidthof

alias simd_width = simdwidthof[DType.float32]()

fn double_array(data: UnsafePointer[Float32], size: Int):
    @parameter
    fn op[width: Int](i: Int):
        var vec = data.load[width=width](i)
        data.store[width=width](i, vec * 2.0)
    
    vectorize[op, simd_width](size)
```

### How It Works
- Processes `simd_width` elements at a time
- Automatically handles remainder (tail elements)
- `width` parameter varies: full width for main loop, 1 for remainder

### With Different Data Types
```mojo
fn normalize[dtype: DType](data: UnsafePointer[Scalar[dtype]], 
                            size: Int, 
                            scale: Scalar[dtype]):
    alias width = simdwidthof[dtype]()
    
    @parameter
    fn op[w: Int](i: Int):
        var vec = data.load[width=w](i)
        data.store[width=w](i, vec / scale)
    
    vectorize[op, width](size)
```

## Parallelism with parallelize

`parallelize` distributes work across CPU cores.

### Basic Usage
```mojo
from algorithm.functional import parallelize

fn parallel_sum(data: UnsafePointer[Int], size: Int) -> Int:
    var partial_sums = UnsafePointer[Int].alloc(size)
    
    @parameter
    fn compute_partial(i: Int):
        partial_sums[i] = data[i] * data[i]  # Square each element
    
    parallelize[compute_partial](size)
    
    # Reduce (sequential)
    var total = 0
    for i in range(size):
        total += partial_sums[i]
    
    partial_sums.free()
    return total
```

### Specifying Worker Count
```mojo
parallelize[task](num_tasks, num_workers=4)  # Use 4 threads
```

### Combining Vectorization and Parallelism
```mojo
from algorithm.functional import parallelize, vectorize
from sys import simdwidthof

alias simd_width = simdwidthof[DType.float32]()

fn parallel_vectorized_process(data: UnsafePointer[Float32], 
                                size: Int, 
                                num_chunks: Int):
    var chunk_size = size // num_chunks
    
    @parameter
    fn process_chunk(chunk_idx: Int):
        var start = chunk_idx * chunk_size
        var end = min(start + chunk_size, size)
        var chunk_len = end - start
        
        @parameter
        fn vectorized_op[width: Int](i: Int):
            var vec = (data + start).load[width=width](i)
            (data + start).store[width=width](i, vec * 2.0)
        
        vectorize[vectorized_op, simd_width](chunk_len)
    
    parallelize[process_chunk](num_chunks)
```

## Compile-Time Metaprogramming

### alias for Compile-Time Constants
```mojo
alias PI = 3.14159265358979
alias MAX_SIZE = 1024
alias FloatVec = SIMD[DType.float32, 8]

# Compile-time function evaluation
fn factorial(n: Int) -> Int:
    if n <= 1: return 1
    return n * factorial(n - 1)

alias FACT_10 = factorial(10)  # Computed at compile time
```

### @parameter for Compile-Time Execution
```mojo
# Compile-time branching
@parameter
if has_avx512():
    use_avx512_kernel()
else:
    use_fallback_kernel()

# Loop unrolling
@parameter
for i in range(4):  # Generates 4 separate statements
    process_lane[i]()
```

### Parameters vs Arguments
```mojo
# Parameters (in []) are compile-time
# Arguments (in ()) are runtime
fn repeat[count: Int](msg: String):
    @parameter
    for i in range(count):  # Unrolled
        print(msg)

repeat[3]("Hello")  # 3 known at compile time
```

### Conditional Compilation
```mojo
from sys import has_avx2, is_nvidia_gpu, is_amd_gpu

fn optimized_compute():
    @parameter
    if is_nvidia_gpu():
        nvidia_kernel()
    elif is_amd_gpu():
        amd_kernel()
    elif has_avx2():
        avx2_kernel()
    else:
        fallback_kernel()
```

## Performance Patterns

### Manual SIMD Loop with Tail Handling
```mojo
fn process_manual(data: UnsafePointer[Float32], size: Int):
    alias width = simdwidthof[DType.float32]()
    
    # Main vectorized loop
    var i = 0
    while i + width <= size:
        var vec = data.load[width=width](i)
        data.store[width=width](i, compute(vec))
        i += width
    
    # Handle remainder (tail)
    while i < size:
        data[i] = compute_scalar(data[i])
        i += 1
```

### Tiled Processing for Cache Efficiency
```mojo
alias TILE_SIZE = 64

fn tiled_matrix_op(A: UnsafePointer[Float32], 
                   B: UnsafePointer[Float32],
                   C: UnsafePointer[Float32],
                   N: Int):
    for i0 in range(0, N, TILE_SIZE):
        for j0 in range(0, N, TILE_SIZE):
            for k0 in range(0, N, TILE_SIZE):
                # Process tile
                for i in range(i0, min(i0 + TILE_SIZE, N)):
                    for j in range(j0, min(j0 + TILE_SIZE, N)):
                        var sum = C[i * N + j]
                        for k in range(k0, min(k0 + TILE_SIZE, N)):
                            sum += A[i * N + k] * B[k * N + j]
                        C[i * N + j] = sum
```

### Memory Alignment for SIMD
```mojo
from memory import UnsafePointer

fn aligned_alloc[T: AnyType](count: Int, alignment: Int) -> UnsafePointer[T]:
    # Allocate with specific alignment for optimal SIMD performance
    return UnsafePointer[T].alloc(count, alignment=alignment)

# Example: align to 32 bytes for AVX
alias AVX_ALIGNMENT = 32
var data = aligned_alloc[Float32](1024, AVX_ALIGNMENT)
```

## Optimization Checklist

1. **Use `fn` instead of `def`** for performance-critical code

2. **Leverage SIMD** with `vectorize()` for data-parallel operations

3. **Use `@parameter`** for compile-time loop unrolling

4. **Add explicit type annotations** for better compiler optimization

5. **Use ownership transfer (`^`)** instead of copying when original isn't needed

6. **Align memory for SIMD**: `alignment = sizeof(type) * simd_width`

7. **Combine parallelization with vectorization** - parallelize outer, vectorize inner

8. **Prefer structs with value semantics** for cache-friendly layouts

9. **Use `@register_passable("trivial")`** for small types fitting in registers

10. **Minimize Python interop calls** by batching operations

### Performance Anti-Patterns to Avoid

```mojo
# BAD: Unnecessary copies
fn process(data: List[Int]) -> List[Int]:
    var result = data  # Copies entire list!
    # ...
    return result

# GOOD: Use references or modify in place
fn process(mut data: List[Int]):
    # Modify data directly
    pass

# BAD: Scalar loop when SIMD possible
for i in range(size):
    data[i] = data[i] * 2.0

# GOOD: Vectorized
@parameter
fn op[width: Int](i: Int):
    var v = ptr.load[width=width](i)
    ptr.store[width=width](i, v * 2.0)
vectorize[op, simd_width](size)
```
