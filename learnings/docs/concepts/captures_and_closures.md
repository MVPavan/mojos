# Closures and Captures in Mojo

## Terminology

| Term | Definition |
|------|------------|
| **Capture** | A single variable accessed from outer scope inside nested function |
| **Closure** | The complete package: function + all its captured variables |

> A closure **has** captures. Captures **belong to** a closure.

---

## Three Closure Types

| Type | Signature | State | Use Case |
|------|-----------|-------|----------|
| **Non-capturing** | `fn() -> T` | None | Top-level pure functions |
| **Capturing** | `fn() capturing [_] -> T` | Reference | @parameter, vectorize, map |
| **Escaping** | `fn() escaping -> T` | Owned copy | Store/return runtime closures |

---

## Capture Modes (Verified)

| Closure Type | Capture Mode | Int Modify Persists? | List Works? |
|--------------|--------------|---------------------|-------------|
| Runtime | **COPY** | ❌ No | ❌ Error |
| `@parameter` | **REFERENCE** | ✅ Yes | ✅ Yes |
| `unified {mut}` | **MUTABLE REF** | ✅ Yes | ✅ Yes |

---

## Non-Capturing

Top-level functions only. No captured variables.

```mojo
fn double(x: Int) -> Int:
    return x * 2

fn execute[f: fn(Int) -> Int](x: Int) -> Int:
    return f(x)

execute[double](5)  # ✅
```

---

## Capturing (@parameter)

Compile-time closures that hold **references** to outer scope.

```mojo
var n = 3
@parameter
fn triple(x: Int) -> Int:
    return x * n  # captures 'n' by reference

fn use[f: fn(Int) capturing [_] -> Int](x: Int) -> Int:
    return f(x)

use[triple](5)  # 15
```

> [!IMPORTANT]
> `@parameter` closures are **ALWAYS** `capturing` type, even without actual captures.

---

## Escaping (Runtime)

Runtime closures that **OWN** copies of captured state. Can be stored and returned.

```mojo
fn make_multiplier(factor: Int) -> fn(Int) escaping -> Int:
    fn mul(x: Int) -> Int:
        return x * factor  # 'factor' COPIED into closure
    return mul^  # transfer ownership

var times2 = make_multiplier(2)
times2(10)  # 20
```

---

## Capture Modifiers

| Mode | Syntax | Behavior |
|------|--------|----------|
| Default | (none) | Copy for runtime, ref for @parameter |
| Mutable | `unified {mut}` | Mutable reference to outer |
| Copy | `unified {var x}` | Snapshot copy |

### Examples

```mojo
# Runtime (copy - changes don't persist)
fn inner(): x += 1  # outer x unchanged

# Parameter (reference - changes persist)  
@parameter
fn inner(): x += 1  # outer x changes!

# Explicit mutable reference
fn modifier() unified {mut}: list.append(99)
```

---

## Key Differences

| Aspect | capturing | escaping |
|--------|-----------|----------|
| **When** | Compile-time | Runtime |
| **State** | Reference to outer | Owned copy |
| **Lifetime** | Tied to outer scope | Independent |
| **Storage** | Inlined | Heap/stack value |

---

## Related
- [[vectorize]] - uses parameter closures
- [[map]] - uses parameter closures
- [[value_ownership]] - ownership and lifetimes
- [[capturing_vs_noncapturing_demo]] - full demo
