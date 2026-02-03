---
name: mojo-max
description: |
  Comprehensive Mojo programming language and MAX framework development skill. Use when:
  (1) Writing Mojo code - systems programming with Python-like syntax
  (2) Translating Python code to high-performance Mojo
  (3) GPU kernel development - NVIDIA, AMD, Apple silicon
  (4) Using MAX for AI model deployment and inference
  (5) Working with SIMD, parallelism, or low-level memory management
  (6) Questions about Mojo ownership, structs, traits, or pointers
  Triggers: .mojo files, "mojo", "MAX framework", "GPU kernel", "SIMD", "LayoutTensor", mentions of Modular
---

# Mojo & MAX Development Skill

Mojo is a systems programming language combining Python syntax with C-level performance. MAX is Modular's AI deployment framework. This skill helps translate Python expertise into idiomatic, high-performance Mojo code.

## Important: Searching the Modular Repository

When the user asks to search through Modular source code, documentation, or examples, or when you need to find specific implementation details, API usage patterns, or real-world examples not covered in these references:
Repo path: repos/modular

1. **Ask the user for the repository path** if not already provided
2. **Search the repository** using `view`, `search`, `file_search` and `bash` tools to explore:
   - `stdlib/` - Mojo standard library source code
   - `examples/` - Official code examples
   - `docs/` - Documentation source
   - `max/` - MAX framework implementation
   - `mojo/` - Mojo compiler and language features
3. **Use grep/find** to locate specific functions, structs, or patterns:
   ```bash
   # Find all uses of a function
   grep -r "vectorize" /path/to/repo --include="*.mojo"
   
   # Find struct definitions
   grep -r "struct DeviceContext" /path/to/repo --include="*.mojo"
   
   # Find examples
   find /path/to/repo/examples -name "*.mojo" | xargs grep "pattern"
   ```
4. **Examine test files** for usage patterns - they often show correct API usage
5. **Check proposals/** for upcoming features and design rationale

Always prefer real source code examples over generated code when available.

If user asks specifically to search internet, or    if even after searching the repository, unable to find the answer then you can search internet for the answer. 

## Quick Reference: Python → Mojo

| Python | Mojo | Notes |
|--------|------|-------|
| `def func():` | `fn func():` | `fn` = strict, `def` = flexible |
| `x = 5` | `var x: Int = 5` | Static typing required in `fn` |
| `class Foo:` | `struct Foo:` | Value semantics, no inheritance |
| `def __init__(self):` | `fn __init__(out self):` | `out` modifier required |
| `list[int]` | `List[Int]` | Capitalized types |
| GC manages memory | Ownership + `^` transfer | Manual control |
| `ValueError` | `Error` | Different error types |
| Dynamic typing | Progressive static typing | Types enforced at compile |

## Core Workflow

### 1. Choose Function Style

```mojo
# def - Python-like, flexible, implicit raises
def greet(name):
    return "Hello, " + name

# fn - strict, performant, explicit types required
fn greet(name: String) -> String:
    return "Hello, " + name
```

**Use `fn`** for performance-critical code. **Use `def`** for prototyping or Python interop.

### 2. Understand Argument Conventions

| Convention | Syntax | Behavior |
|------------|--------|----------|
| `read` | `fn f(x: Int)` | Immutable reference (default for `fn`) |
| `mut` | `fn f(mut x: Int)` | Mutable reference, changes visible to caller |
| `owned` | `fn f(owned x: String)` | Takes ownership, use `^` to transfer |
| `out` | `fn __init__(out self)` | Uninitialized, must be initialized |

### 3. Define Structs with Proper Lifecycle

```mojo
@fieldwise_init  # Auto-generates field-wise constructor
struct Point(Copyable, Stringable):
    var x: Float64
    var y: Float64
    
    fn __str__(self) -> String:
        return "(" + str(self.x) + ", " + str(self.y) + ")"
```

### 4. Transfer Ownership with `^`

```mojo
fn consume(owned s: String):
    print(s)

fn main():
    var msg = "Hello"
    consume(msg^)  # Transfer ownership
    # msg is now uninitialized - cannot use
```

## When to Read Reference Files

| Task | Reference File |
|------|----------------|
| Learning fn/def, var, types, structs, traits | [language-basics.md](references/language-basics.md) |
| Understanding ownership, borrowing, lifetimes | [ownership-memory.md](references/ownership-memory.md) |
| Working with pointers (Pointer, UnsafePointer, etc.) | [pointers.md](references/pointers.md) |
| SIMD, vectorize, parallelize, compile-time | [performance-cpu.md](references/performance-cpu.md) |
| GPU kernels, DeviceContext, grids/blocks | [gpu-programming.md](references/gpu-programming.md) |
| LayoutTensor, TensorCores, shared memory | [gpu-advanced.md](references/gpu-advanced.md) |
| Calling Python from Mojo or vice versa | [python-interop.md](references/python-interop.md) |
| MAX Serve, inference, model deployment | [max-framework.md](references/max-framework.md) |
| Common pitfalls, translation patterns | [translation-patterns.md](references/translation-patterns.md) |

## Essential Patterns

### SIMD Vectorization
```mojo
from algorithm.functional import vectorize
alias simd_width = simdwidthof[DType.float32]()

fn process(data: UnsafePointer[Float32], size: Int):
    @parameter
    fn op[width: Int](i: Int):
        var v = data.load[width=width](i)
        data.store[width=width](i, v * 2.0)
    vectorize[op, simd_width](size)
```

### Parallel Execution
```mojo
from algorithm.functional import parallelize

fn parallel_work():
    @parameter
    fn task(i: Int):
        compute(i)
    parallelize[task](num_tasks)
```

### Basic GPU Kernel
```mojo
from gpu.host import DeviceContext
from gpu import block_idx, thread_idx, global_idx

fn vector_add(out: UnsafePointer[Float32, MutAnyOrigin],
              a: UnsafePointer[Float32, MutAnyOrigin],
              b: UnsafePointer[Float32, MutAnyOrigin],
              size: Int):
    var idx = global_idx.x
    if idx < size:
        out[idx] = a[idx] + b[idx]

def main():
    ctx = DeviceContext()
    # ... allocate buffers, copy data ...
    ctx.enqueue_function[vector_add, vector_add](
        out_buf, a_buf, b_buf, size,
        grid_dim=((size + 255) // 256,),
        block_dim=(256,)
    )
    ctx.synchronize()
```

### Python Interop
```mojo
from python import Python

def use_numpy():
    np = Python.import_module("numpy")
    arr = np.array([1, 2, 3, 4, 5])
    print(arr.mean())
```

## Common Pitfalls

1. **No top-level code** - wrap in `def main():`
2. **Constructor needs `out self`** - `fn __init__(out self):`
3. **`let` removed** - use only `var`
4. **Types are capitalized** - `Int`, `String`, `Float64`
5. **No list comprehensions** - use explicit loops
6. **Error not ValueError** - `raise Error("msg")`
7. **Struct not class** - value semantics, no inheritance

## File Organization

```
project/
├── main.mojo          # Entry point with def main()
├── utils.mojo         # Helper functions/structs
└── pixi.toml          # Package management (recommended)
```

## Build & Run

```bash
# Using pixi (recommended)
pixi init
pixi add max
pixi run mojo main.mojo

# Direct execution
mojo main.mojo

# Compile to binary
mojo build main.mojo -o app
./app
```
