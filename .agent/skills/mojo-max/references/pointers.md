# Pointers in Mojo

## Table of Contents
- [Pointer Types Overview](#pointer-types-overview)
- [Pointer (Safe Reference)](#pointer-safe-reference)
- [OwnedPointer (Exclusive Ownership)](#ownedpointer-exclusive-ownership)
- [ArcPointer (Shared Ownership)](#arcpointer-shared-ownership)
- [UnsafePointer (Manual Control)](#unsafepointer-manual-control)
- [Pointer Selection Guide](#pointer-selection-guide)

## Pointer Types Overview

| Type | Owns Memory | Allocates | Nullable | Use Case |
|------|-------------|-----------|----------|----------|
| `Pointer` | No | No | No | Safe reference to existing value |
| `OwnedPointer` | Yes | Yes | No | Single ownership, auto cleanup |
| `ArcPointer` | Shared | Yes | No | Multiple owners, ref counted |
| `UnsafePointer` | Manual | Optional | Yes | Low-level control, FFI, arrays |

## Pointer (Safe Reference)

Safe pointer that references a value it doesn't own. Tracks origins for compile-time safety.

```mojo
from memory import Pointer

fn process(ptr: Pointer[Int]):
    print(ptr[])  # Dereference with []

fn main():
    var value = 42
    var ptr = Pointer(to=value)  # Point to existing value
    process(ptr)
    print(value)  # value unchanged, still accessible
```

### Use Cases
- Store reference to related type (e.g., iterator → collection)
- Pass memory location to external code
- Avoid copying large values

## OwnedPointer (Exclusive Ownership)

Smart pointer with exclusive ownership. Automatically deallocates on destruction.

```mojo
from memory import OwnedPointer

struct LargeData:
    var buffer: List[Float64]
    
    fn __init__(out self, size: Int):
        self.buffer = List[Float64](capacity=size)
        for i in range(size):
            self.buffer.append(0.0)

fn main():
    # Allocates on heap, moves value into pointer
    var data = OwnedPointer(LargeData(1000000))
    
    # Access via dereference
    print(len(data[].buffer))
    
    # Can move but not copy
    var data2 = data^  # Transfer ownership
    # data is now invalid
    
    # Automatically freed when data2 goes out of scope
```

### Characteristics
- Cannot be copied (single ownership enforced)
- Can be moved with `^`
- Stored type must be `Movable` or `Copyable`
- Automatic cleanup via destructor

## ArcPointer (Shared Ownership)

Atomic Reference Counted pointer. Multiple owners share the same data.

```mojo
from memory import ArcPointer

fn main():
    # Create shared data
    var shared = ArcPointer(Dict[String, String]())
    
    # Copy creates another owner (increments ref count)
    var shared2 = shared  # Both point to same data
    
    # Modify through either pointer
    shared[]["key"] = "value"
    print(shared2[]["key"])  # "value" - same data
    
    # Freed when last owner destroyed
```

### Use Cases
- Shared resources with unclear last owner
- Self-referential data structures (linked lists, trees)
- When `Optional[OwnedPointer]` is needed (workaround)

### Thread Safety Note
Reference count operations are atomic (thread-safe), but accessing underlying data is NOT. Use synchronization when sharing across threads.

## UnsafePointer (Manual Control)

C-like pointer for low-level memory manipulation. You manage all memory.

### Basic Usage
```mojo
from memory import UnsafePointer
from memory.unsafe_pointer import alloc

fn main():
    # Allocate space for 10 integers
    var ptr = alloc[Int](10)
    
    # Initialize each element
    for i in range(10):
        (ptr + i).init_pointee_copy(i * 10)
    
    # Access via subscript
    print(ptr[0])   # 0
    print(ptr[5])   # 50
    
    # Modify values
    ptr[3] = 999
    
    # MUST free when done
    for i in range(10):
        (ptr + i).destroy_pointee()
    ptr.free()
```

### Lifecycle States

```
Uninitialized → Null → Allocated → Initialized → Dangling
     ↓           ↓         ↓            ↓            ↓
  declare     ptr={}    alloc()    init_*()      free()
```

### Key Operations

```mojo
from memory.unsafe_pointer import alloc

# Allocation
var ptr = alloc[Float64](100)           # Heap allocation

# Point to existing value (no allocation)
var existing = 42
var ptr2 = UnsafePointer(to=existing)

# Initialization
ptr.init_pointee_copy(value)      # Copy value in
ptr.init_pointee_move(value^)     # Move value in
ptr.init_pointee_move_from(src)   # Move from another pointer

# Destruction
ptr.destroy_pointee()             # Call destructor
var val = ptr.take_pointee()      # Move value out

# Pointer arithmetic
var next = ptr + 1                # Offset by 1 element
ptr += 5                          # In-place offset

# Type conversion
var opaque = ptr.bitcast[NoneType]()  # Create void* equivalent
var typed = opaque.bitcast[Int]()     # Cast back

# SIMD operations
var vec = ptr.load[width=8](offset)        # Load 8 values
ptr.store[width=8](offset, simd_values)    # Store SIMD vector
var strided = ptr.strided_load[width=4](stride=3)  # Every 3rd value
```

### Working with Origins

```mojo
# External origin for heap allocations
var heap_ptr = alloc[Int](1)  # origin = MutOrigin.external

# Origin from existing value
var value = 100
var ref_ptr = UnsafePointer(to=value)  # origin = origin_of(value)

# FFI with explicit origin
fn get_c_buffer() -> UnsafePointer[UInt8, MutOrigin.external]:
    return external_call["get_buffer", 
                         UnsafePointer[UInt8, MutOrigin.external]]()
```

### Python Interop

```mojo
from python import Python

def process_numpy():
    np = Python.import_module("numpy")
    arr = np.array([1, 2, 3, 4, 5])
    
    # Get pointer to NumPy's buffer
    ptr = arr.ctypes.data.unsafe_get_as_pointer[DType.int64]()
    
    for i in range(5):
        print(ptr[i])
```

### Opaque Pointers (void*)

```mojo
# OpaquePointer = UnsafePointer[NoneType]
var str_ptr = UnsafePointer(to=my_string)
var opaque = str_ptr.bitcast[NoneType]()

# Pass to C function expecting void*
external_call["process_data", NoneType](opaque, size)

# Cast back when type is known
var recovered = opaque.bitcast[String]()
```

## Pointer Selection Guide

### Use `Pointer` when:
- Need reference without ownership
- Implementing iterators or views
- Want compiler lifetime tracking

### Use `OwnedPointer` when:
- Single, clear ownership of heap data
- Automatic cleanup desired
- Value doesn't need sharing

### Use `ArcPointer` when:
- Multiple code paths need same data
- Ownership transfer is complex
- Building shared data structures

### Use `UnsafePointer` when:
- Building array-like structures
- FFI with C/C++ or Python
- Maximum performance control needed
- Other pointer types don't fit

## Common Patterns

### Dynamic Array with UnsafePointer
```mojo
struct DynamicArray[T: Movable & Copyable]:
    var data: UnsafePointer[T, MutOrigin.external]
    var size: Int
    var capacity: Int
    
    fn __init__(out self, capacity: Int):
        self.capacity = capacity
        self.size = 0
        self.data = UnsafePointer[T, MutOrigin.external].alloc(capacity)
    
    fn append(mut self, owned value: T):
        if self.size >= self.capacity:
            self._grow()
        (self.data + self.size).init_pointee_move(value^)
        self.size += 1
    
    fn __getitem__(self, idx: Int) -> ref [self] T:
        return self.data[idx]
    
    fn __del__(owned self):
        for i in range(self.size):
            (self.data + i).destroy_pointee()
        self.data.free()
```

### Shared Cache with ArcPointer
```mojo
from memory import ArcPointer

struct Cache:
    var data: ArcPointer[Dict[String, String]]
    
    fn __init__(out self):
        self.data = ArcPointer(Dict[String, String]())
    
    fn get(self, key: String) -> Optional[String]:
        if key in self.data[]:
            return self.data[][key]
        return None
    
    fn set(self, key: String, value: String):
        self.data[][key] = value
```
