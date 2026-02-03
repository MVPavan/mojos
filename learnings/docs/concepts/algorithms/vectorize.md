# Vectorize Algorithm

## Overview

The `vectorize` function is a high-performance primitive in Mojo's `algorithm` package designed to simplify SIMD (Single Instruction, Multiple Data) loops. It abstracts away the complexity of handling:
1.  **Main Vector Loop**: Processing elements in chunks of `simd_width`.
2.  **Unrolling**: Reducing loop overhead by repeating the body `unroll_factor` times.
3.  **Boundary/Residue Handling**: Automatically processing remaining elements that don't fit into a full vector.

## Usage

### Syntax

```mojo
from algorithm import vectorize

vectorize[simd_width, size=size, unroll_factor=1](size, func)
```

-   **`simd_width`**: (Int) The number of elements to process in a single SIMD operation. Usually derived from `sys.simd_width_of[DType]()`.
-   **`func`**: A function with signature `fn[width: Int](idx: Int) unified {mut} -> None`.
    -   `width`: The actual width being processed (can be `simd_width` or smaller for residue).
    -   `idx`: The current index in the loop.
-   **`size`**: (Int, optional in `[]` but required in `()`) The total number of elements to process. If passed as a static parameter (`size=...`), Mojo can optimize the residue loop.
-   **`unroll_factor`**: (Int, default 1) How many times to unroll the main loop.

### Basic Example

```mojo
from algorithm import vectorize
from sys import simd_width_of

fn main():
    alias width = simd_width_of[DType.int32]()
    var size = 100
    var ptr = DTypePointer[DType.int32].alloc(size)

    @parameter
    fn closure[w: Int](idx: Int) unified {mut}:
        # Efficient combined store
        ptr.store[width=w](idx, 1)

    vectorize[width](size, closure)
```

## How It Works

### Dynamic Size (Standard)
When `size` is only known at runtime:
1.  **Vector Loop**: Runs from `0` to `align_down(size, width)` in steps of `width`.
    -   Calls `func[width](idx)`.
2.  **Residue Loop**: Runs from the end of the vector loop to `size` in steps of `1`.
    -   Calls `func[1](idx)`.

*Example Trace (Size=10, Width=4)*:
```
func[4](0)
func[4](4)
func[1](8)  # Scalar cleanup
func[1](9)  # Scalar cleanup
```

### Static Size (Optimized)
When `size` is known at compile time (`size=...` parameter):
1.  **Vector Loop**: Same as dynamic.
2.  **Optimized Residue**: If the remainder is a power of 2 (e.g., 2, 4, 8), Mojo generates a single smaller SIMD operation instead of a scalar loop.

*Example Trace (Size=10, Width=4)*:
```
func[4](0)
func[4](4)
func[2](8)  # Optimized SIMD[2] cleanup!
```

### Unrolling (`unroll_factor`)

Loop unrolling is an optimization that repeats the loop body multiple times within a single iteration. This reduces the "loop overhead" (checking the condition, incrementing the counter, and jumping back) relative to the useful work done.

**Why use it?**
-   **Pros**: Reduces branch prediction failures and instruction overhead. exposing more instruction-level parallelism to the CPU.
-   **Cons**: Increases binary size (code bloat).

**Visual Comparison** (Size=16, Width=4):

**Without Unrolling (`unroll_factor=1`)**:
```python
# Pseudo-code
for i in range(0, 16, 4):
    # HEADER CHECKS (Overhead)
    closure(i)
    # JUMP BACK (Overhead)
```
*Total Overheads: 4*

**With Unrolling (`unroll_factor=2`)**:
```python
# Pseudo-code
for i in range(0, 16, 8): # Step size doubles!
    # HEADER CHECKS (Overhead)
    closure(i)      # i = 0, 8
    closure(i + 4)  # i = 4, 12
    # JUMP BACK (Overhead)
```
*Total Overheads: 2 (50% reduction)*

## Best Practices

1.  **Use `simd_width_of[DType]`**: Always query the system for the optimal width for your specific data type.
2.  **Pass Static `size`**: If possible, passing `size` as a parameter allows for better residue optimization.
3.  **Unified Trait**: Your worker function must be `unified` (usually `unified {mut}` if capturing) to be compatible with `vectorize`.
4.  **Memory Operations**: Use `SIMD` load/store operations matching the `width` parameter inside your worker for maximum performance.
