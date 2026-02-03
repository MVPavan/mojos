# Ownership and Memory Management

## Table of Contents
- [Ownership Model Overview](#ownership-model-overview)
- [Argument Conventions](#argument-conventions)
- [The Transfer Operator ^](#the-transfer-operator-)
- [Value Semantics vs Reference Semantics](#value-semantics-vs-reference-semantics)
- [Lifecycle Methods](#lifecycle-methods)
- [Origins and Lifetimes](#origins-and-lifetimes)

## Ownership Model Overview

Mojo uses an ownership system similar to Rust to ensure memory safety without garbage collection:

1. **Every value has exactly one owner at a time**
2. **When the owner's lifetime ends, Mojo destroys the value**
3. **References extend the owner's lifetime as needed**

```mojo
fn main():
    var s = String("Hello")  # s owns the String
    process(s)               # s is borrowed (read-only reference)
    print(s)                 # s still valid
    
    consume(s^)              # s transfers ownership
    # print(s)               # ERROR: s is uninitialized
```

## Argument Conventions

### `read` (default for `fn`)
Passes an immutable reference. No copy occurs for large types.

```mojo
fn print_length(s: String):  # 'read' is implicit
    print(len(s))
    # s[0] = 'X'  # ERROR: cannot mutate

fn main():
    var msg = "Hello"
    print_length(msg)  # Borrowed, not copied
    print(msg)         # Still valid
```

### `mut` (mutable reference)
Changes affect the original value.

```mojo
fn append_exclaim(mut s: String):
    s += "!"

fn main():
    var msg = "Hello"
    append_exclaim(msg)
    print(msg)  # "Hello!"
```

### `owned` (takes ownership)
Function takes full control. Original becomes uninitialized.

```mojo
fn consume(owned s: String):
    print("Consuming:", s)
    # s is destroyed when function exits

fn main():
    var msg = "Hello"
    consume(msg^)      # ^ transfers ownership
    # print(msg)       # ERROR: msg is uninitialized
```

### `out` (uninitialized output)
Used in constructors. Parameter starts uninitialized, must be initialized.

```mojo
struct Point:
    var x: Float64
    var y: Float64
    
    fn __init__(out self, x: Float64, y: Float64):
        self.x = x  # Must initialize all fields
        self.y = y
```

### `ref` (parametric mutability)
For generic code working with both mutable and immutable references.

```mojo
fn get_first[T: CollectionElement](ref items: List[T]) -> ref [items] T:
    return items[0]
```

## The Transfer Operator ^

The `^` operator explicitly ends a variable's lifetime and transfers ownership.

### Basic Transfer
```mojo
fn take(owned x: String):
    print(x)

fn main():
    var a = "Hello"
    take(a^)        # Transfer ownership
    # a is now uninitialized
```

### Transfer in Expressions
```mojo
fn main():
    var a = String("Hello")
    var b = a^      # Move a into b
    # a is uninitialized, b owns the value
    print(b)
```

### When Transfer is Required
- Passing to `owned` parameters
- Moving into collections
- Returning owned values from functions

### When Transfer is NOT Required
- Trivial types (`Int`, `Float64`, `Bool`) - copied automatically
- Newly constructed values - already owned by destination

```mojo
fn take_int(owned x: Int):
    print(x)

fn main():
    var n = 42
    take_int(n)   # No ^ needed, Int is trivial (copied)
    print(n)      # Still valid
```

## Value Semantics vs Reference Semantics

### Value Semantics (Mojo default)
Each copy is independent. Modifying one doesn't affect others.

```mojo
fn main():
    var a = List[Int](1, 2, 3)
    var b = a  # Creates a copy
    b.append(4)
    print(len(a))  # 3 - unchanged
    print(len(b))  # 4
```

### Reference Semantics (explicit)
Multiple variables share the same data via pointers.

```mojo
from memory import ArcPointer

fn main():
    var shared = ArcPointer(List[Int](1, 2, 3))
    var also_shared = shared  # Same underlying data
    also_shared[].append(4)
    print(len(shared[]))  # 4 - shared change
```

## Lifecycle Methods

### Constructor: `__init__`
```mojo
fn __init__(out self):
    # Initialize all fields
    self.field1 = value1
    self.field2 = value2
```

### Copy Constructor: `__copyinit__`
Called when copying a value.

```mojo
fn __copyinit__(out self, existing: Self):
    # Deep copy all fields
    self.data = existing.data.copy()
```

### Move Constructor: `__moveinit__`
Called when moving a value with `^`.

```mojo
fn __moveinit__(out self, owned existing: Self):
    # Take ownership of existing's resources
    self.data = existing.data
    # existing's fields are now moved-from
```

### Destructor: `__del__`
Called when value's lifetime ends.

```mojo
fn __del__(owned self):
    # Cleanup resources
    self.data.free()
```

### Complete Example
```mojo
struct DynamicArray(Movable, Copyable):
    var data: UnsafePointer[Int, MutOrigin.external]
    var size: Int
    
    fn __init__(out self, size: Int):
        self.size = size
        self.data = UnsafePointer[Int, MutOrigin.external].alloc(size)
        for i in range(size):
            (self.data + i).init_pointee_copy(0)
    
    fn __copyinit__(out self, existing: Self):
        self.size = existing.size
        self.data = UnsafePointer[Int, MutOrigin.external].alloc(self.size)
        for i in range(self.size):
            (self.data + i).init_pointee_copy(existing.data[i])
    
    fn __moveinit__(out self, owned existing: Self):
        self.size = existing.size
        self.data = existing.data
    
    fn __del__(owned self):
        for i in range(self.size):
            (self.data + i).destroy_pointee()
        self.data.free()
```

## Origins and Lifetimes

Origins track where references point, ensuring memory safety.

### Origin Basics
```mojo
fn get_ref(ref x: Int) -> ref [x] Int:
    return x  # Return reference with same origin as input

fn main():
    var a = 42
    var r = get_ref(a)  # r's origin is tied to a
    print(r)
```

### External Origin
For heap allocations and FFI:

```mojo
from memory.unsafe_pointer import alloc

fn main():
    # MutOrigin.external indicates manually managed memory
    var ptr = alloc[Int](10)  # Returns UnsafePointer with external origin
    # ... use ptr ...
    ptr.free()  # Must free manually
```

### Origin of Self
For methods returning references to internal data:

```mojo
struct Container:
    var items: List[Int]
    
    fn get_first(ref self) -> ref [self] Int:
        return self.items[0]  # Origin tied to self
```

## Argument Exclusivity

You cannot pass the same value as both `mut` and another reference:

```mojo
fn process(mut a: Int, b: Int):
    a += b

fn main():
    var x = 10
    # process(x, x)  # ERROR: x cannot be mut and read simultaneously
    
    var y = x  # Make a copy
    process(x, y)  # OK
```

## Memory Safety Guarantees

Mojo's ownership system prevents:
- **Use-after-free**: Compiler tracks when values are destroyed
- **Double-free**: Single ownership prevents multiple frees
- **Dangling references**: Origins ensure references outlive their targets
- **Data races**: Exclusivity prevents simultaneous mutable access
