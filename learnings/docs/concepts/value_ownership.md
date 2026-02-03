# Mojo Value Ownership Guide

Mojo's ownership system ensures memory safety without garbage collection by tracking how values are created, shared, and destroyed.

## Core Concepts

| Concept | Description |
|---------|-------------|
| **Value Semantics** | Each variable owns its own independent copy of data |
| **References** | Borrowed access to values without taking ownership |
| **Ownership Transfer** | Moving ownership from one variable to another using `^` |
| **Lifetimes** | Compiler-tracked scope determining when values are destroyed |

---

## Argument Conventions

Mojo uses explicit argument conventions to control how values are passed to functions:

### 1. `read` (Default) - Immutable Reference

```mojo
fn read_only(data: MyStruct):  # 'read' is the default
    print(data.value)          # Can read
    # data.value = 10          # ERROR: Cannot modify
```

- **No copy made** - efficient for large types
- **Cannot modify** the value
- Original remains valid after call

### 2. `mut` - Mutable Reference

```mojo
fn mutate(mut data: MyStruct):
    data.value = 999  # Modifies the original!
```

- **No copy made** - changes affect original
- Requires `mut` keyword at both declaration and call site
- Subject to **exclusivity rule**: no aliasing allowed

### 3. `var` - Takes Ownership

```mojo
fn consume(var data: MyStruct):
    data.value *= 2  # We own it, can do anything
    # data is destroyed when function ends
```

Two ways to call:
```mojo
consume(original.copy())  # Pass a copy (original remains valid)
consume(original^)        # Transfer ownership (original becomes invalid)
```

---

## The Transfer Operator `^`

The `^` sigil transfers ownership, making the original variable unusable:

```mojo
var source = MyStruct(100)
var destination = source^  # Ownership transferred via __moveinit__
# print(source.value)      # ERROR: use of uninitialized value 'source'
```

### When to Use `^`

| Scenario | Use `^`? | Reason |
|----------|----------|--------|
| Large struct, no longer needed | ✅ Yes | Avoids expensive copy |
| Returning from a function | ✅ Yes | Transfers to caller efficiently |
| Need original after call | ❌ No | Use `.copy()` instead |

---

## Lifecycle Methods

### `__copyinit__` - Copy Constructor

Called when creating a copy (via `.copy()` or implicit copy):

```mojo
fn __copyinit__(out self, existing: Self):
    self.data = existing.data  # Deep copy heap data
```

### `__moveinit__` - Move Constructor

Called when ownership is transferred with `^`:

```mojo
fn __moveinit__(out self, deinit existing: Self):
    self.data = existing.data^  # Take ownership of internals
```

### `__del__` - Destructor

Called when a value's lifetime ends:

```mojo
fn __del__(deinit self):
    # Cleanup resources (files, memory, etc.)
```

---

## Argument Exclusivity

When a function receives a mutable reference (`mut`), it cannot receive another reference to the same value:

```mojo
fn append_twice(mut target: String, suffix: String):
    target += suffix

var text = String("hello")
# append_twice(text, text)  # ERROR: aliasing violation
```

**Solution**: Create an explicit copy if needed:
```mojo
var suffix = text  # or text.copy()
append_twice(text, suffix)  # OK
```

---

## ASAP Destruction

Mojo follows an **ASAP (As Soon As Possible)** destruction policy. Values are destroyed immediately after their **last use**, rather than waiting for the end of the scope.

```mojo
fn example():
    var a = Resource("A")
    var b = Resource("B")
    
    print(a.value)
    # 'a' is destroyed HERE (last use), not at end of function
    
    consume(b)
    # 'b' is destroyed inside consume (or after if borrowed)
    
    print("Function ending")
```

This aggressive lifetime management reduces resource usage and is a key difference from C++ (RAII at end of scope) or Python (GC).

---

## Quick Reference

| Convention | Keyword | Copy? | Can Modify? | Original After Call |
|------------|---------|-------|-------------|---------------------|
| Read | (default) | No | No | Valid |
| Mutable | `mut` | No | Yes | Valid (modified) |
| Owned (copy) | `var` + `.copy()` | Yes | Yes | Valid |
| Owned (move) | `var` + `^` | No | Yes | **Invalid** |

---

## Example Code

See the comprehensive examples in [`scratchpad/value_ownership_examples.mojo`](file:///data/nvidia_local/opensource/mojos/scratchpad/value_ownership_examples.mojo) which demonstrates:

1. Value semantics (copy on assignment)
2. Immutable references (`read`)
3. Mutable references (`mut`)
4. Ownership transfer (`var` + `^`)
5. Argument exclusivity
6. Copy constructor (`__copyinit__`)
7. Move constructor (`__moveinit__`)
8. Destruction order
9. Practical ownership patterns
