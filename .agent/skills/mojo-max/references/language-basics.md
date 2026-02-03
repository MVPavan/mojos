# Mojo Language Basics

## Table of Contents
- [Functions: fn vs def](#functions-fn-vs-def)
- [Variables](#variables)
- [Types](#types)
- [Structs](#structs)
- [Traits](#traits)
- [Control Flow](#control-flow)
- [Error Handling](#error-handling)

## Functions: fn vs def

### `def` - Python-style functions
```mojo
def greet(name):              # Types optional
    return "Hello, " + name   # Implicit raises

def process(data):
    if len(data) == 0:
        raise Error("Empty")  # Can raise without declaration
    return data[0]
```

### `fn` - Strict, performant functions
```mojo
fn greet(name: String) -> String:  # Types required
    return "Hello, " + name        # Non-raising by default

fn process(data: List[Int]) raises -> Int:  # Must declare raises
    if len(data) == 0:
        raise Error("Empty")
    return data[0]
```

### Key Differences

| Aspect | `def` | `fn` |
|--------|-------|------|
| Type annotations | Optional | Required |
| Raises | Implicit (always assumed) | Must declare `raises` |
| Arguments | Mutable copies by default | Immutable references by default |
| Performance | Good | Optimal (more optimization) |

### When to Use
- **`fn`**: Performance-critical code, library APIs, GPU kernels
- **`def`**: Prototyping, scripts, Python interop

## Variables

### Declaration with `var`
```mojo
var x: Int = 10        # Explicit type
var name = "Alice"     # Type inferred as String
var count: Int         # Declared but uninitialized (must init before use)

x = 20                 # Mutation allowed
# x = "hello"          # ERROR: type mismatch
```

### No `let` keyword
The `let` keyword for immutable variables has been **removed**. Use `var` for all variables.

### Compile-time constants with `alias`
```mojo
alias PI = 3.14159265358979
alias MAX_SIZE = 1024
alias FloatType = Float32  # Type alias

# Compile-time computation
fn fib(n: Int) -> Int:
    if n <= 1: return n
    return fib(n-1) + fib(n-2)

alias FIB_20 = fib(20)  # Computed at compile time
```

## Types

### Primitive Types
```mojo
var i: Int = 42              # Platform-sized integer
var i8: Int8 = 127           # 8-bit signed
var u32: UInt32 = 1000       # 32-bit unsigned
var f: Float64 = 3.14        # 64-bit float
var b: Bool = True           # Boolean
var s: String = "Hello"      # String
```

### SIMD Types
```mojo
var scalar: Float32 = 1.0                    # Same as SIMD[DType.float32, 1]
var vec4 = SIMD[DType.float32, 4](1, 2, 3, 4)  # 4-element vector
var result = vec4 * 2.0                      # Element-wise operations
```

### Collection Types
```mojo
var list = List[Int](1, 2, 3, 4)
list.append(5)
print(list[0])  # 1

var dict = Dict[String, Int]()
dict["key"] = 42
```

### Optional Types
```mojo
var maybe: Optional[Int] = None
maybe = 42
if maybe:
    print(maybe.value())
```

## Structs

### Basic Struct
```mojo
struct Point:
    var x: Float64
    var y: Float64
    
    fn __init__(out self, x: Float64, y: Float64):
        self.x = x
        self.y = y
    
    fn distance(self) -> Float64:
        return (self.x**2 + self.y**2).sqrt()
```

### Using `@fieldwise_init`
```mojo
@fieldwise_init  # Auto-generates constructor
struct Rectangle:
    var width: Float64
    var height: Float64
    
    fn area(self) -> Float64:
        return self.width * self.height

# Usage: var rect = Rectangle(width=10.0, height=5.0)
```

### Lifecycle Methods
```mojo
struct Resource(Copyable, Movable):
    var data: UnsafePointer[Int, MutOrigin.external]
    var size: Int
    
    fn __init__(out self, size: Int):
        self.size = size
        self.data = UnsafePointer[Int, MutOrigin.external].alloc(size)
    
    fn __copyinit__(out self, existing: Self):
        self.size = existing.size
        self.data = UnsafePointer[Int, MutOrigin.external].alloc(self.size)
        for i in range(self.size):
            (self.data + i).init_pointee_copy(existing.data[i])
    
    fn __moveinit__(out self, owned existing: Self):
        self.size = existing.size
        self.data = existing.data
        # existing.data is now moved, don't access it
    
    fn __del__(owned self):
        self.data.free()
```

## Traits

### Defining Traits
```mojo
trait Drawable:
    fn draw(self):
        ...
    
    fn get_color(self) -> String:
        ...

trait Resizable:
    fn resize(mut self, factor: Float64):
        ...
```

### Implementing Traits
```mojo
struct Circle(Drawable):
    var radius: Float64
    var color: String
    
    fn __init__(out self, radius: Float64, color: String):
        self.radius = radius
        self.color = color
    
    fn draw(self):
        print("Drawing circle with radius:", self.radius)
    
    fn get_color(self) -> String:
        return self.color
```

### Generic Functions with Traits
```mojo
fn render[T: Drawable](item: T):
    item.draw()

# Trait composition
fn process[T: Copyable & Stringable](item: T):
    var copy = item  # Uses Copyable
    print(str(copy)) # Uses Stringable
```

### Essential Standard Library Traits
- `Copyable` - can be copied with `.copy()`
- `Movable` - can be moved with `^`
- `Stringable` - has `__str__()` method
- `Equatable` - supports `==` and `!=`
- `Comparable` - supports `<`, `>`, `<=`, `>=`
- `Hashable` - can be used as dict key
- `Sized` - has `__len__()` method

## Control Flow

### Conditionals
```mojo
if x > 0:
    print("positive")
elif x < 0:
    print("negative")
else:
    print("zero")

# Ternary-style (no direct equivalent, use if/else)
var result = x if condition else y  # In def functions
```

### Loops
```mojo
# Range-based for loop
for i in range(10):
    print(i)

# Iterating collections
for item in list:
    print(item[])  # Note: iterator returns references

# While loop
var i = 0
while i < 10:
    print(i)
    i += 1
```

### Compile-time Loops with `@parameter`
```mojo
@parameter
for i in range(4):  # Unrolled at compile time
    process_lane[i]()
```

## Error Handling

### Raising Errors
```mojo
fn divide(a: Int, b: Int) raises -> Int:
    if b == 0:
        raise Error("Division by zero")
    return a // b
```

### Handling Errors
```mojo
def safe_divide(a: Int, b: Int) -> Int:
    try:
        return divide(a, b)
    except e:
        print("Error:", e)
        return 0
```

### Context Managers
```mojo
with open("file.txt", "r") as f:
    var content = f.read()
```
