# Captures and Closures

> For a comprehensive deep-dive, see [closures_deep_dive.md](closures_deep_dive.md)

## Quick Summary

A **closure** is a function combined with an environment (captured variables).

### Two Closure Types in Mojo

| Type | Decorator | Type Signature | Capture | Use Case |
|------|-----------|----------------|---------|----------|
| **Parameter** | `@parameter` | `fn() capturing [_]` | By reference | `vectorize`, `map`, compile-time |
| **Runtime** | (none) | `fn() escaping` | By copy | Dynamic dispatch, returning closures |

### Capture Semantics

```mojo
# 1. Implicit (borrow) - default, read-only
fn reader():
    print(x)  # OK to read, can't modify

# 2. Mutable capture
fn mutator() unified {mut}:
    x += 1  # OK to modify

# 3. Copy capture (snapshot)
fn copier() unified {var x}:
    # 'x' is a copy, original unchanged

# 4. Copy for parametric closures
@__copy_capture(x)
@parameter
fn param_copier() -> Int:
    return x  # copied at creation time
```

### Type Signatures

```mojo
# Accept any closure matching signature
fn execute[func: fn(Int) capturing [_] -> Int](n: Int) -> Int:
    return func(n)
```

## Demo

Run the comprehensive demo:
```bash
pixi run mojo learnings/concept_demos/closures_comprehensive_demo.mojo
```
