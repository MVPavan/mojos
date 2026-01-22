# Algorithm Package Learnings

## Overview
The `std.algorithm` package provides high-performance primitives for functional programming, loop transformations, reductions, and memory operations optimized for modern hardware (CPU/GPU).

## Key Components

### 1. Functional Operations

#### `map`
- **Purpose**: Simple index-based iteration with functional interface
- **Signature**: `map[func: fn(Int) capturing [origins] -> None](size: Int)`
- **Use Case**: Cleaner than raw `for` loops when capturing context
- **Example**:
  ```mojo
  var data = alloc[Int](10)
  
  @parameter
  fn worker(idx: Int):
      data[idx] += 1
      
  map[worker](10)
  ```

#### `elementwise`
- **Purpose**: N-dimensional iteration with automatic SIMD vectorization
- **Key Features**:
  - Abstracts loop nesting and vectorization
  - Supports CPU and GPU targets
  - Handles boundary conditions automatically
  - Chunks inner dimension by SIMD width
- **Signature**: `elementwise[func, simd_width](shape: IndexList[rank])`
- **Example**:
  ```mojo
  var shape = Index(10, 10)  # 2D: 10x10
  alias simd_width = 4
  
  @parameter
  fn worker[width: Int, rank: Int, alignment: Int](idx: IndexList[rank]):
      # idx: starting coordinates [row, col]
      # width: elements to process in inner dimension
      pass
      
  elementwise[worker, simd_width](shape)
  ```
- **Chunking Behavior**: For a 10-element dimension with SIMD width 4:
  - Processes: 4 + 4 + 1 + 1 (vectorized + cleanup)

#### `vectorize`
- **Purpose**: SIMD-optimized loops with explicit width control
- **Features**: Main vector loop + cleanup loop, supports unrolling
- **[Deep Dive](./vectorize.md)**: Detailed guide on `vectorize`, residue handling, and unrolling.

#### `parallelize`
- **Purpose**: Multi-threaded work distribution for CPU-intensive tasks
- **Signature**: `parallelize[func: fn(Int) capturing [origins] -> None](num_work_items: Int)`
- **Use Case**: Heavy independent computations (e.g., image processing, scientific calc)
- **Example**:
  ```mojo
  var results = List[Int](capacity=1000)
  # ... (fill list) ...
  
  @parameter
  fn process(idx: Int):
      # Heavy computation on independent index
      results[idx] = expensive_calc(results[idx])
      
  parallelize[process](1000)
  ```
- **Variants**: `parallelize` (async), `sync_parallelize` (blocking)

### 2. Loop Transformations

#### `tile`
- **Purpose**: Loop tiling (blocking) for cache locality
- **Signature**: `tile[func, tile_size_list](offset, limit)`
- **Key Note**: Static tiling requires explicit cleanup tile (e.g., `VariadicList(4, 1)`)
- **Example**:
  ```mojo
  @parameter
  fn worker[width: Int](off: Int): ...
  
  # Tile with 4, fallback to 1 for remainder
  tile[worker, VariadicList(4, 1)](0, 10)
  ```

#### `unswitch`
- **Purpose**: Hoists boolean checks out of functions ("compile-time if" at runtime)
- **Signature**: `unswitch[func](dynamic_bool)`
- **Use Case**: Selecting optimized/safe paths without branching inside the loop
- **Example**:
  ```mojo
  unswitch[worker](is_fast_mode) # Compiles 2 versions, picks 1
  ```

#### `tile_and_unswitch`
- **Purpose**: Fused optimization (Fast path for main tiles, Safe path for cleanup)
- **Use Case**: Aligned SIMD for main loop, unaligned/masked for cleanup
- **Example**:
  ```mojo
  # 0..8 runs with True (Fast), 8..10 runs with False (Safe)
  tile_and_unswitch[worker, 4](0, 10)
  ```

#### `tile_middle_unswitch_boundaries`
- **Purpose**: Specialized 3-part tiling for convolutions (Left, Middle, Right)
- **Signature**: `tile_middle_unswitch_boundaries[func, tile_size, size]()`
- **Use Case**: Avoiding padding checks in the center of an image/tensor
- **Behavior**:
  - **Left**: `func[..., True, False]` (Left Edge Check)
  - **Middle**: `func[..., False, False]` (No Edge Checks - FAST)
  - **Right**: `func[..., False, True]` (Right Edge Check)

### 3. Reductions

#### `reduce`
- **Purpose**: General-purpose buffer aggregation
- **Custom Functions**: Supports user-defined reduction operations

#### `map_reduce`
- **Purpose**: Fused generation + reduction
- **Benefit**: Avoids intermediate allocations

#### `reduce_boolean`
- **Purpose**: Boolean checks with short-circuiting
- **Examples**: `all()`, `any()`

### 4. Memory Operations

#### `parallel_memcpy`
- **Purpose**: Multi-threaded memory copy
- **Threshold**: ~4KB (auto-switches serial/parallel)

## Design Patterns

### SIMD Awareness
- Functions like `vectorize` and `elementwise` handle SIMD width automatically
- Cleanup loops handle non-aligned boundaries
- Use `sys.simd_width_of[DType]()` for optimal width

### Origin Tracking
- Functions use `OriginSet` to track captured data lifetimes
- Ensures memory safety when capturing pointers/references

### Target Abstraction
- `target` parameter: "cpu" or "gpu"
- Enables cross-device code with same API

## Best Practices

1. **Use `fn` over `def`**: Strict typing and better performance
2. **Prefer `comptime` over `alias`**: Modern Mojo convention
3. **Move semantics**: Use `^` transfer operator; explicit `copy()` when needed
4. **SIMD width**: Match hardware capabilities for best performance
5. **Elementwise for tensors**: Better than manual nested loops
6. **Map for simple iteration**: Cleaner than `for` when capturing context

## Performance Considerations

- **Vectorization**: 4-16x speedup on numeric operations
- **Parallelization**: Scales with available cores
- **Tiling**: Reduces cache misses significantly
- **GPU dispatch**: Automatic when `DeviceContext` provided

## Common Patterns

### Processing a buffer
```mojo
var data = alloc[Float32](1024)

@parameter
fn process(idx: Int):
    data[idx] = data[idx] * 2.0
    
map[process](1024)
```

### Multi-dimensional computation
```mojo
var shape = Index(height, width)

@parameter
fn compute[width: Int, rank: Int, alignment: Int](idx: IndexList[rank]):
    # Process width elements starting at idx
    pass
    
elementwise[compute, simd_width](shape)
```

## Related Files
- Source: `repos/modular/mojo/stdlib/std/algorithm/`
- Tests: `repos/modular/mojo/stdlib/test/algorithm/`
- Docs: `repos/modular/docs/eng-design/docs/elementwise-ops.md`
