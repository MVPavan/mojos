# Closures in Mojo: A Deep Dive

A **closure** is a function bundled with its *environment*—the set of variables it "captures" from the surrounding scope. Mojo has a sophisticated closure system with two distinct closure types, multiple capture semantics, and integration with the lifetime/origin system.

---

## Two Closure Types

Mojo distinguishes between two fundamentally different closure types:

### 1. Parameter Closures (Compile-time)

Parameter closures are the backbone of Mojo's metaprogramming and high-performance algorithms like `vectorize`, `parallelize`, and `map`. They:

- Are always denoted by `@parameter` decorator
- Have type `fn() capturing [_] -> T`
- Are captured by **reference** (not copied)
- Can be used as **parameter values** (compile-time)
- Get **inlined** by the compiler for zero overhead

```mojo
fn use_closure[func: fn(Int) capturing [_] -> Int](num: Int) -> Int:
    return func(num)

fn create_parametric_closure():
    var x = 1

    @parameter
    fn add(i: Int) -> Int:
        return x + i  # captures 'x' by reference

    var y = use_closure[add](2)  # 'add' passed as parameter
    print(y)  # prints 3
```

> [!IMPORTANT]
> Without `@parameter`, the closure is dynamic and cannot be passed as a compile-time parameter.

### 2. Runtime Closures (Dynamic)

Runtime closures are first-class values that can be stored, passed around, and called dynamically. They:

- Capture values by **copy** (invoke copy constructors)
- Own their capture state
- Have type `fn() escaping -> T`
- Can be safely returned from functions

```mojo
fn outer(b: Bool, x: String) -> fn() escaping -> None:
    fn closure():
        print(x)  # 'x' captured by copy

    fn bare_function():
        print("hello")  # nothing captured

    if b:
        return closure^  # can be safely returned
    return bare_function  # function pointers convert to closures
```

---

## The "Code + Data" Mental Model

| Type | What It Is | Memory Size | Overhead |
|------|------------|-------------|----------|
| **Static Function** | Just code (no captures) | Zero | None |
| **Parameter Closure** | Code + references to outer variables | Non-zero | Inlined away |
| **Runtime Closure** | Code + copied values | Non-zero | Dynamic dispatch |

When you define a nested function that captures variables, the compiler synthesizes a **struct** containing:
1. **Fields** for every captured variable
2. A **`__call__` method** with your function's code

---

## Capture Semantics

Mojo provides precise control over *how* variables are captured.

### 1. Implicit Capture (Borrow) — Default

By default, nested functions capture outer variables by **immutable reference**:

```mojo
fn demo_implicit():
    var x = 10
    fn reader():
        print(x)   # OK: read access
        # x += 1   # ERROR: cannot modify borrowed capture
    reader()
```

### 2. Mutable Capture — `unified {mut}`

For algorithms like `vectorize`, use `unified {mut}` to modify captured variables:

```mojo
fn demo_mutable():
    var count = 0
    fn incrementer() unified {mut}:
        count += 1  # OK: mutable capture
    incrementer()
    incrementer()
    print(count)    # prints 2
```

### 3. Copy Capture — `unified {var varname}`

Capture a **snapshot** of a variable's value at closure creation time:

```mojo
fn demo_copy():
    var val = 100
    fn copier() unified {var val}:
        # 'val' is a local copy, immutable by default
        var local = val
        local += 50
        print(local)  # 150
    copier()
    print(val)        # 100 (unchanged)
```

### 4. Copy Capture for Parameter Closures — `@__copy_capture`

For parametric closures (marked with `@parameter`), use the `@__copy_capture` decorator:

```mojo
fn foo(x: Int):
    var z = x

    @__copy_capture(z)
    @parameter
    fn formatter() -> Int:
        return z      # 'z' captured by copy at closure creation
    
    z = 2             # this modification doesn't affect the closure
    print(formatter())  # prints 5, not 2

fn main():
    foo(5)
```

---

## Type Signatures for Closures

Because closures carry data, their types are richer than plain function pointers.

### Basic Syntax

```mojo
fn() -> ReturnType                    # function pointer (no captures)
fn() capturing [_] -> ReturnType      # parametric closure (any captures)
fn() escaping -> ReturnType           # runtime closure (owns captures)
```

### The `[_]` Origin Specifier

The `[_]` in `capturing [_]` represents an **origin set**—the set of origins for values captured by the closure. This allows the compiler to correctly extend the lifetimes of captured values.

```mojo
fn use_closure[func: fn(Int) capturing [_] -> Int](num: Int) -> Int:
    return func(num)
```

### Accepting Closures as Parameters

```mojo
# Accept any closure with specific signature
fn execute[func: fn() capturing [_] -> None](f: func):
    f()

# Accept closure that may raise
fn execute_raises[func: fn() capturing [_] raises -> None](f: func) raises:
    f()
```

---

## `capturing` vs `unified`

| Keyword | Purpose | Use Case |
|---------|---------|----------|
| **`unified {capture_list}`** | Specifies capture semantics | Used with `std.algorithm` functions (`vectorize`, `map`) |
| **`capturing [origins]`** | Specifies closure type signature | Used in parametric type declarations for accepting closures |

### The `unified` Keyword

`unified` makes a nested function "context-agnostic" for use with standard library algorithms:

```mojo
fn demo_vectorize():
    var total = 0
    
    @parameter
    fn accumulate[width: Int](idx: Int) unified {mut}:
        # Can be passed to vectorize because of 'unified {mut}'
        total += 1
    
    vectorize[accumulate, 8](100)
    print(total)  # 100
```

---

## Origins and Lifetimes with Closures

Mojo's origin system tracks the lifetime of captured values:

```mojo
fn use_ptr[func: fn(Int) capturing [_] -> Int](num: Int) -> Int:
    return func(num)
```

The `[_]` origin specifier tells the compiler:
- The closure captures values with **some unknown set of origins**
- The compiler must **extend the lifetimes** of those captured values
- The captured values must remain **valid** while the closure exists

This integration with the lifetime system prevents:
- Dangling references from captured variables
- Use-after-free bugs
- Premature destruction of captured values

---

## Historical Evolution

Mojo's closure model has evolved significantly:

| Version | Changes |
|---------|---------|
| **Early** | `@noncapturing` and `@closure` decorators |
| **v0.7.0** | Removed decorators, refined closure model with `escaping` type |
| **Current** | Two distinct types: `capturing [_]` (parametric) and `escaping` (runtime) |

---

## Practical Examples

### Using Closures with `vectorize`

```mojo
from algorithm import vectorize

fn sum_array(data: DTypePointer[DType.float32], size: Int) -> Float32:
    var total: Float32 = 0
    
    @parameter
    fn accumulate[width: Int](idx: Int) unified {mut}:
        @parameter
        for i in range(width):
            total += data[idx + i]
    
    vectorize[accumulate, 8](size)
    return total
```

### Returning a Closure

```mojo
fn make_adder(n: Int) -> fn(Int) escaping -> Int:
    fn add(x: Int) -> Int:
        return x + n  # 'n' captured by copy
    return add^

fn main():
    var add5 = make_adder(5)
    print(add5(10))  # 15
```

### Closure as Callback

```mojo
fn process_items[callback: fn(Int) capturing [_] -> None](items: List[Int]):
    for item in items:
        callback(item)

fn main():
    var sum = 0
    
    @parameter
    fn accumulate(x: Int) unified {mut}:
        sum += x
    
    var items = List[Int](1, 2, 3, 4, 5)
    process_items[accumulate](items)
    print(sum)  # 15
```

---

## Key Takeaways

1. **Two types**: Parameter closures (compile-time, inlined) vs runtime closures (dynamic, owning)
2. **Capture modes**: Immutable borrow (default), mutable (`unified {mut}`), copy (`unified {var}`)
3. **Type syntax**: `fn() capturing [_]` for parametric, `fn() escaping` for runtime
4. **Use `@parameter`** to make a closure usable as a compile-time parameter
5. **Use `unified {mut}`** when you need to mutate captured variables with algorithms
6. **Origins track lifetimes** of captured values to ensure memory safety

---

## References

- [Mojo Manual - Functions](file:///data/nvidia_local/opensource/mojos/repos/modular/mojo/docs/manual/functions.mdx)
- [Mojo Manual - @parameter decorator](file:///data/nvidia_local/opensource/mojos/repos/modular/mojo/docs/manual/decorators/parameter.mdx)
- [Mojo Manual - @__copy_capture decorator](file:///data/nvidia_local/opensource/mojos/repos/modular/mojo/docs/manual/decorators/copy-capture.mdx)
- [Mojo Manual - Lifetimes, Origins, References](file:///data/nvidia_local/opensource/mojos/repos/modular/mojo/docs/manual/values/lifetimes.mdx)
