# Tiling and Unswitching Strategies in Mojo

Mojo's `algorithm.functional` module provides powerful primitives for loop optimization. These functions allow you to separate logic (what to calculate) from schedule (how to iterate), enabling high-performance optimizations like cache tiling and branch hoisting without rewriting your core logic.

## 1. `tile`
**Purpose**: Divides a loop into smaller "tiles" to improve cache locality. It iterates over a range in steps of `tile_size`.

**Key Behavior**:
*   For **Static** tile sizes (passed as parameters `[]`), you **MUST** provide a list of descending sizes (e.g., `(4, 1)`) if you want to handle residues (items that don't fit in the main tile). It does *not* automatically clean up residues.
*   For **Dynamic** tile sizes (passed as args `()`), it automatically handles the residue.

**Example**:
```mojo
from algorithm.functional import tile

@parameter
fn print_tile[width: Int](offset: Int):
    print("Processing", width, "items at", offset)

fn main():
    # Process 10 items. Try chunks of 4. Fallback to 1 for leftovers.
    # Output: 4 at 0, 4 at 4, 1 at 8, 1 at 9
    tile[print_tile, VariadicList(4, 1)](0, 10) 
```

## 2. `unswitch`
**Purpose**: "Hoists" a boolean check out of a function. Instead of checking `if flag:` inside a hot loop, it generates two completely separate versions of the function—one where `flag` is `True`, one where `False`—and picks the right one *once* at runtime.

**Use Case**: When you have a runtime configuration (e.g., `is_debug_mode`) that stays constant for the duration of a heavy operation.

**Example**:
```mojo
from algorithm.functional import unswitch

@parameter
fn worker[is_fast: Bool]():
    # This check happens at COMPILE TIME in the generated code
    @parameter
    if is_fast:
        print("SIMD Optimized Path")
    else:
        print("Scalar Safe Path")

fn main():
    var dynamic_cfg = True # Can be runtime value
    
    # At runtime, this checks dynamic_cfg ONCE, then jumps 
    # to the fully optimized 'True' block or 'False' block.
    unswitch[worker](dynamic_cfg)
```

## 3. `tile_and_unswitch`
**Purpose**: Fuses `tile` and `unswitch`. It assumes your operation has a "fast mode" (e.g., aligned SIMD) and a "safe mode" (e.g., masked/scalar).
*   **Main Body**: Calls the function with `unswitch=True` (Fast).
*   **Residue/Leftovers**: Calls the function with `unswitch=False` (Safe).

**Use Case**: Implementing your own `vectorize` or processing arrays where the pointer alignment is guaranteed for the middle but not the end.

**Example**:
```mojo
from algorithm.functional import tile_and_unswitch

@parameter
fn op[width: Int, is_aligned: Bool](offset: Int, limit: Int):
    if is_aligned:
        print("Vector store at", offset)
    else:
        print("Masked store at", offset)

fn main():
    # 0..8 uses 'True' (Fast), 8..10 uses 'False' (Safe)
    tile_and_unswitch[op, 4](0, 10)
```

## 4. `tile_middle_unswitch_boundaries`
**Purpose**: Specialized for **Convolutions** or stencil operations. It divides the iteration space into three parts:
1.  **Left Boundary**: Padding/Checks needed (Flag = `True`).
2.  **Middle**: Safe zone, no padding needed (Flag = `False`).
3.  **Right Boundary**: Padding/Checks needed (Flag = `True`).

**Why**: Checking "Am I at the image edge?" for every pixel is slow. This splits the loops so the middle 90% of the image runs with ZERO checks.

**Example**:
```mojo
from algorithm.functional import tile_middle_unswitch_boundaries

@parameter
fn conv_part[width: Int, is_left_edge: Bool, is_right_edge: Bool](offset: Int):
    if is_left_edge or is_right_edge:
        print("Safe computing at", offset, "with checks")
    else:
        print("FAST computing at", offset, "NO checks")

fn main():
    # Image width 10, Tile size 4.
    # Left (0-4): Boundary
    # Middle (4-8): Safe
    # Right (8-10): Boundary
    tile_middle_unswitch_boundaries[conv_part, tile_size=4, size=10]()
```

## 5. Concept: Tiling vs SIMD
It is common to confuse Tiling and SIMD, as both involve "chunking" data. However, they solve different problems at different levels of hardware:

| Feature | **SIMD (Vectorization)** | **Tiling (Blocking)** |
| :--- | :--- | :--- |
| **Problem Solved** | **CPU Throughput**. CPUs can do math on multiple numbers at once (e.g., 4x Int32). | **Memory Latency**. RAM is slow; L1/L2 Cache is fast. Tiling keeps active data in fast cache. |
| **Mechanism** | Uses **Special Registers** (AVX-512, NEON) to execute 1 instruction on N data items. | Uses **Loop Transformation** to work on a small "block" of data repeatedly before moving on. |
| **Typical Size** | Tiny. `simd_width` (e.g., 4, 8, 16 elements). Determined by CPU architecture. | Medium. `tile_size` (e.g., 64, 256, 1024 elements). Determined by Cache Size. |
| **Mojo Function** | `vectorize` | `tile` |

**How they work together**:
You typically **Tile** a large array (to keep chunks in L1 cache) and then **Vectorize** the math inside that tile (to compute it efficiently).

```mojo
# Conceptual Hierarchy
tile[...]:              # 1. Block: Split 1,000,000 items into 1024-item chunks (fits in L1 Cache)
    vectorize[...]:     # 2. Vector: Split 1024 items into 8-item vectors (fits in CPU Register)
        SIMD_Instruction # 3. Execute: Add 8 integers in 1 cycle
```

## 6. Comparison: `tile_and_unswitch` vs `tile_middle_unswitch_boundaries`
The key difference lies in the **structure** of the optimization (Alignment vs Padding).

| Feature | **`tile_and_unswitch`** | **`tile_middle_unswitch_boundaries`** |
| :--- | :--- | :--- |
| **Logic** | **Alignment** | **Padding / Stencil** |
| **Problem** | "Is my pointer aligned?" | "Do I have enough neighbors?" |
| **Structure** | Start is aligned (Safe/Fast).<br>Only the **End** might be unaligned (Slow). | **Start** (Left) is missing neighbors (Slow).<br>**End** (Right) is missing neighbors (Slow).<br>Only **Middle** is safe (Fast). |
| **Flow** | **FAST** $\rightarrow$ **SLOW** | **SLOW** $\rightarrow$ **FAST** $\rightarrow$ **SLOW** |

