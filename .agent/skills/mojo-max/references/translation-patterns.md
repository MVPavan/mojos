# Python to Mojo Translation Patterns

## Table of Contents
- [Syntax Differences](#syntax-differences)
- [Common Translations](#common-translations)
- [Pitfalls and Gotchas](#pitfalls-and-gotchas)
- [Pattern Cookbook](#pattern-cookbook)
- [Migration Checklist](#migration-checklist)

## Syntax Differences

### Function Definitions

```python
# Python
def greet(name, excited=False):
    msg = f"Hello, {name}"
    if excited:
        msg += "!"
    return msg
```

```mojo
# Mojo (def style - more flexible)
def greet(name: String, excited: Bool = False) -> String:
    var msg = "Hello, " + name
    if excited:
        msg += "!"
    return msg

# Mojo (fn style - strict, performant)
fn greet(name: String, excited: Bool = False) -> String:
    var msg = "Hello, " + name
    if excited:
        msg += "!"
    return msg
```

### Class → Struct

```python
# Python
class Point:
    def __init__(self, x, y):
        self.x = x
        self.y = y
    
    def distance(self):
        return (self.x**2 + self.y**2) ** 0.5
```

```mojo
# Mojo
struct Point:
    var x: Float64
    var y: Float64
    
    fn __init__(out self, x: Float64, y: Float64):
        self.x = x
        self.y = y
    
    fn distance(self) -> Float64:
        return (self.x**2 + self.y**2).sqrt()
```

### Variables

```python
# Python
x = 10          # Dynamic
x = "hello"     # Allowed - dynamic typing
PI = 3.14159    # Convention for constant (but mutable)
```

```mojo
# Mojo
var x: Int = 10     # Static type
# x = "hello"       # ERROR: type mismatch
alias PI = 3.14159  # True compile-time constant
```

### Collections

```python
# Python
numbers = [1, 2, 3, 4, 5]
numbers.append(6)
first = numbers[0]

data = {"key": "value", "count": 42}
data["new"] = "item"
```

```mojo
# Mojo
var numbers = List[Int](1, 2, 3, 4, 5)
numbers.append(6)
var first = numbers[0]

var data = Dict[String, String]()
data["key"] = "value"
data["new"] = "item"
```

### Loops

```python
# Python
for i in range(10):
    print(i)

for item in items:
    process(item)

squares = [x**2 for x in range(10)]
```

```mojo
# Mojo
for i in range(10):
    print(i)

for item in items:
    process(item[])  # Note: iterator returns reference

# No comprehensions - use explicit loop
var squares = List[Int]()
for x in range(10):
    squares.append(x**2)
```

### Error Handling

```python
# Python
def divide(a, b):
    if b == 0:
        raise ValueError("Division by zero")
    return a / b

try:
    result = divide(10, 0)
except ValueError as e:
    print(f"Error: {e}")
```

```mojo
# Mojo
fn divide(a: Int, b: Int) raises -> Int:
    if b == 0:
        raise Error("Division by zero")  # Error, not ValueError
    return a // b

def safe_divide(a: Int, b: Int) -> Int:
    try:
        return divide(a, b)
    except e:
        print("Error:", e)
        return 0
```

## Common Translations

### String Formatting

```python
# Python
name = "Alice"
age = 30
msg = f"Name: {name}, Age: {age}"
```

```mojo
# Mojo (no f-strings yet)
var name = "Alice"
var age = 30
var msg = "Name: " + name + ", Age: " + str(age)

# Or using print directly
print("Name:", name, "Age:", age)
```

### Optional/None

```python
# Python
def find(items, target):
    for item in items:
        if item == target:
            return item
    return None

result = find(items, "x")
if result is not None:
    process(result)
```

```mojo
# Mojo
fn find(items: List[String], target: String) -> Optional[String]:
    for item in items:
        if item[] == target:
            return item[]
    return None

var result = find(items, "x")
if result:
    process(result.value())
```

### Type Checking

```python
# Python
if isinstance(x, int):
    handle_int(x)
elif isinstance(x, str):
    handle_str(x)
```

```mojo
# Mojo - use traits or compile-time parameters
fn process[T: Stringable](x: T):
    print(str(x))

# Or with compile-time branching
fn handle[T: AnyType](x: T):
    @parameter
    if T == Int:
        handle_int(x)
    elif T == String:
        handle_str(x)
```

### Lambda/Closures

```python
# Python
numbers = [1, 2, 3, 4, 5]
doubled = list(map(lambda x: x * 2, numbers))
evens = list(filter(lambda x: x % 2 == 0, numbers))
```

```mojo
# Mojo - use nested functions with @parameter
fn process_list(data: List[Int]) -> List[Int]:
    var result = List[Int]()
    
    @parameter
    fn double(x: Int) -> Int:
        return x * 2
    
    for item in data:
        result.append(double(item[]))
    
    return result
```

## Pitfalls and Gotchas

### 1. No Top-Level Code
```python
# Python - works
print("Hello")
x = 10
```

```mojo
# Mojo - ERROR
# print("Hello")  # Not allowed at top level

def main():  # Must wrap in function
    print("Hello")
    var x = 10
```

### 2. Constructor Requires `out self`
```python
# Python
def __init__(self, x):
    self.x = x
```

```mojo
# Mojo - out required
fn __init__(out self, x: Int):  # 'out' is mandatory
    self.x = x
```

### 3. `let` Has Been Removed
```mojo
# OLD Mojo - no longer valid
# let x = 10  # ERROR: 'let' removed

# Current Mojo
var x = 10  # Use var for all variables
alias CONST = 10  # Use alias for compile-time constants
```

### 4. Types Are Capitalized
```python
# Python
x: int = 10
y: float = 3.14
s: str = "hello"
```

```mojo
# Mojo - capitalized
var x: Int = 10
var y: Float64 = 3.14
var s: String = "hello"
```

### 5. Iterator Returns References
```python
# Python
for item in items:
    print(item)  # item is the value
```

```mojo
# Mojo
for item in items:
    print(item[])  # item is reference, [] dereferences
```

### 6. No Inheritance in Structs
```python
# Python
class Animal:
    def speak(self): pass

class Dog(Animal):
    def speak(self):
        return "Woof"
```

```mojo
# Mojo - use traits instead
trait Speakable:
    fn speak(self) -> String:
        ...

struct Dog(Speakable):
    fn speak(self) -> String:
        return "Woof"
```

### 7. Different Error Types
```python
# Python
raise ValueError("msg")
raise TypeError("msg")
raise RuntimeError("msg")
```

```mojo
# Mojo - just Error
raise Error("msg")  # Single error type
```

### 8. No Dict/Set Literals
```python
# Python
d = {"a": 1, "b": 2}
s = {1, 2, 3}
```

```mojo
# Mojo - no literals
var d = Dict[String, Int]()
d["a"] = 1
d["b"] = 2

var s = Set[Int]()
s.add(1)
s.add(2)
```

### 9. Explicit Mutability
```python
# Python - default mutable
def modify(data):
    data.append(1)  # Modifies original
```

```mojo
# Mojo - explicit mut
fn modify(mut data: List[Int]):  # Must declare mut
    data.append(1)
```

### 10. Global Variables Limited
```python
# Python
counter = 0
def increment():
    global counter
    counter += 1
```

```mojo
# Mojo - no global keyword, restructure code
struct Counter:
    var value: Int
    
    fn __init__(out self):
        self.value = 0
    
    fn increment(mut self):
        self.value += 1
```

## Pattern Cookbook

### Singleton Pattern
```mojo
struct Config:
    var debug: Bool
    var max_connections: Int
    
    fn __init__(out self):
        self.debug = False
        self.max_connections = 100
    
    @staticmethod
    fn instance() -> ref [StaticConstantOrigin] Config:
        var config = Config()
        return config

# Usage
alias config = Config.instance()
```

### Builder Pattern
```mojo
@fieldwise_init
struct RequestBuilder:
    var url: String
    var method: String
    var headers: Dict[String, String]
    
    fn with_url(owned self, url: String) -> Self:
        self.url = url
        return self^
    
    fn with_method(owned self, method: String) -> Self:
        self.method = method
        return self^
    
    fn build(self) -> Request:
        return Request(self.url, self.method, self.headers)
```

### Resource Management (RAII)
```mojo
struct FileHandle:
    var handle: Int
    
    fn __init__(out self, path: String) raises:
        self.handle = open_file(path)
    
    fn __del__(owned self):
        close_file(self.handle)  # Automatic cleanup
    
    fn read(self) -> String:
        return read_file(self.handle)
```

## Migration Checklist

When converting Python to Mojo:

- [ ] Wrap top-level code in `def main():`
- [ ] Add type annotations to all function parameters and returns
- [ ] Change `class` to `struct`
- [ ] Add `out self` to `__init__` methods
- [ ] Replace `let` with `var` (if migrating old Mojo)
- [ ] Capitalize types: `int` → `Int`, `str` → `String`
- [ ] Replace list comprehensions with explicit loops
- [ ] Change `ValueError` etc. to `Error`
- [ ] Add `mut` to parameters that need modification
- [ ] Use `[]` to dereference iterator items
- [ ] Replace inheritance with traits
- [ ] Add `^` for ownership transfer where needed
- [ ] Replace f-strings with concatenation
- [ ] Test performance-critical paths with `fn` instead of `def`
