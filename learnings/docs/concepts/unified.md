# Unified Functions

## Overview

The `unified` keyword in Mojo is a function declaration modifier that indicates a function is **execution-context agnostic**. It guarantees that the function can be compiled and dispatched to different hardware backends (like CPU threads or GPU kernels) without modification.

This is a critical trait for high-performance algorithms in the standard library, such as `vectorize`, `parallelize`, and GPU kernels, which need to "move" your code to different execution units.

## Syntax

```mojo
fn my_function(...) unified {capture_list}:
    ...
```

-   **`unified`**: The keyword itself.
-   **`{capture_list}`**: Optional but common. Specifies how outer variables are captured.

## Capture Lists

When using `unified` with closures (nested functions), you often need to be explicit about capturing behavior:

| Syntax | Meaning | Description |
| :--- | :--- | :--- |
| `unified` | Default capture | Captures based on standard Mojo rules (borrowed by default). |
| `unified {read}` | Read-only capture | All captured variables are immutable (like `let`). |
| `unified {mut}` | Mutable capture | All captured variables are mutable (like `var`). |
| `unified {read x, mut y}` | Mixed capture | `x` is read-only, `y` is mutable. |
| `capturing [_]` | Universal capture | Captures everything (syntax alias often used with unified). |

## Usage Standard Library

You will most commonly encounter `unified` when using `std.algorithm` primitives.

### Example: `vectorize`

The `vectorize` function signature requires a `unified` worker:

```mojo
# std/algorithm/functional.mojo
fn vectorize[
    func: fn[width: Int] (idx: Int) unified -> None, # <--- Requirement
    ...
](...)
```

If you pass a function that is *not* `unified`, the compiler will error because it cannot guarantee safety across SIMD lanes or threads.

### Example in User Code

```mojo
from algorithm import vectorize

fn main():
    var x = 0
    
    # Must be 'unified {mut}' because we modify 'x'
    # and we want it compatible with 'vectorize'
    @parameter
    fn worker[w: Int](i: Int) unified {mut}:
        x += 1
        
    vectorize[4](16, worker)
```

## "Unified" vs "GPU"

While `unified` allows code to run on GPUs, it doesn't *force* it to. It simply satisfies the interface requirements for the compiler to generate the necessary kernel code *if* requested by a GPU dispatch function.
