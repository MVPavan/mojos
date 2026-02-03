# Python Interoperability

## Table of Contents
- [Calling Python from Mojo](#calling-python-from-mojo)
- [Working with Python Objects](#working-with-python-objects)
- [NumPy Integration](#numpy-integration)
- [Calling Mojo from Python](#calling-mojo-from-python)
- [Type Conversions](#type-conversions)
- [Best Practices](#best-practices)

## Calling Python from Mojo

### Import Python Modules
```mojo
from python import Python

def use_python():
    # Import standard library
    var os = Python.import_module("os")
    var json = Python.import_module("json")
    
    # Import third-party packages
    var np = Python.import_module("numpy")
    var pd = Python.import_module("pandas")
    var requests = Python.import_module("requests")
```

### Handle Import Errors
```mojo
def safe_import():
    try:
        var torch = Python.import_module("torch")
        print("PyTorch loaded")
    except e:
        print("PyTorch not available:", e)
```

### Call Python Functions
```mojo
def python_operations():
    var math = Python.import_module("math")
    
    # Call functions
    var result = math.sqrt(16.0)
    print(result)  # 4.0
    
    # Access constants
    var pi = math.pi
    print(pi)
```

### Create Python Objects
```mojo
def create_objects():
    # Lists
    var py_list = Python.list(1, 2, 3, 4)
    py_list.append(5)
    
    # Dicts
    var py_dict = Python.dict()
    py_dict["key"] = "value"
    
    # Tuples (immutable)
    var py_tuple = Python.tuple(1, "hello", 3.14)
```

## Working with Python Objects

### PythonObject Type
All Python values are `PythonObject` in Mojo:

```mojo
from python import PythonObject

def work_with_objects():
    var np = Python.import_module("numpy")
    var arr: PythonObject = np.array([1, 2, 3])
    
    # Call methods
    var mean = arr.mean()
    var reshaped = arr.reshape(3, 1)
    
    # Access attributes
    var shape = arr.shape
    var dtype = arr.dtype
```

### Iteration
```mojo
def iterate_python():
    var py_list = Python.list(1, 2, 3, 4, 5)
    
    for item in py_list:
        print(item)
```

### Indexing and Slicing
```mojo
def indexing():
    var py_list = Python.list(10, 20, 30, 40, 50)
    
    # Index access
    var first = py_list[0]
    var last = py_list[-1]
    
    # Slicing (returns PythonObject)
    var slice = py_list[1:4]
```

## NumPy Integration

### Create and Manipulate Arrays
```mojo
def numpy_basics():
    var np = Python.import_module("numpy")
    
    # Create arrays
    var arr = np.array([1.0, 2.0, 3.0, 4.0])
    var zeros = np.zeros((3, 3))
    var ones = np.ones((2, 4))
    var arange = np.arange(0, 10, 0.5)
    
    # Operations
    var squared = arr ** 2
    var sum_val = arr.sum()
    var mean_val = arr.mean()
```

### Access NumPy Data from Mojo
```mojo
def access_numpy_data():
    var np = Python.import_module("numpy")
    var arr = np.array([1, 2, 3, 4, 5], dtype=np.int64)
    
    # Get raw pointer to numpy data
    var ptr = arr.ctypes.data.unsafe_get_as_pointer[DType.int64]()
    
    # Now can use Mojo's fast operations
    for i in range(5):
        print(ptr[i])
```

### Modify NumPy Arrays from Mojo
```mojo
def modify_numpy():
    var np = Python.import_module("numpy")
    var arr = np.zeros(1000, dtype=np.float32)
    
    # Get pointer
    var ptr = arr.ctypes.data.unsafe_get_as_pointer[DType.float32]()
    
    # Modify using Mojo SIMD
    from algorithm.functional import vectorize
    alias simd_width = simdwidthof[DType.float32]()
    
    @parameter
    fn fill[width: Int](i: Int):
        var vec = SIMD[DType.float32, width](Float32(i))
        ptr.store[width=width](i, vec)
    
    vectorize[fill, simd_width](1000)
    
    print(arr[:10])  # Verify modification
```

## Calling Mojo from Python

### Export Mojo Functions (Preview)
```mojo
from python import PythonObject
from python.bindings import PythonModuleBuilder

fn factorial(n: Int) -> Int:
    if n <= 1: return 1
    return n * factorial(n - 1)

@export
fn PyInit_mojo_math() -> PythonObject:
    var m = PythonModuleBuilder("mojo_math")
    m.def_function[factorial]("factorial", docstring="Compute n!")
    return m.finalize()
```

### Build and Use
```bash
# Build the module
mojo build --shared -o mojo_math.so mojo_math.mojo
```

```python
# In Python
import mojo_math
result = mojo_math.factorial(10)
print(result)  # 3628800
```

## Type Conversions

### Mojo → Python
```mojo
def mojo_to_python():
    # Automatic conversions
    var py_int = PythonObject(42)
    var py_float = PythonObject(3.14)
    var py_str = PythonObject("hello")
    var py_bool = PythonObject(True)
    
    # Lists
    var mojo_list = List[Int](1, 2, 3)
    var py_list = Python.list()
    for item in mojo_list:
        py_list.append(item[])
```

### Python → Mojo
```mojo
def python_to_mojo():
    var np = Python.import_module("numpy")
    var py_val = np.int64(42)
    
    # Explicit conversion
    var mojo_int = Int(py_val)
    
    # Float conversion
    var py_float = Python.evaluate("3.14159")
    var mojo_float = Float64(py_float)
    
    # String conversion
    var py_str = Python.evaluate("'hello'")
    var mojo_str = String(py_str)
```

### Conversion Table

| Mojo Type | Python Type | Notes |
|-----------|-------------|-------|
| `Int` | `int` | Direct conversion |
| `Float64` | `float` | Direct conversion |
| `Bool` | `bool` | Direct conversion |
| `String` | `str` | Direct conversion |
| `List[T]` | `list` | Manual iteration |
| `Dict[K,V]` | `dict` | Manual iteration |
| `PythonObject` | Any Python | Universal wrapper |

## Best Practices

### 1. Minimize Cross-Boundary Calls
```mojo
# BAD: Many small calls
def slow_approach():
    var np = Python.import_module("numpy")
    var result = 0.0
    for i in range(10000):
        result += Float64(np.sqrt(Float64(i)))  # Slow!

# GOOD: Batch operations
def fast_approach():
    var np = Python.import_module("numpy")
    var arr = np.arange(10000)
    var result = np.sqrt(arr).sum()  # Single call
```

### 2. Use Native Mojo for Hot Paths
```mojo
def hybrid_approach():
    var np = Python.import_module("numpy")
    
    # Load data with Python
    var data = np.load("data.npy")
    
    # Get pointer for Mojo processing
    var ptr = data.ctypes.data.unsafe_get_as_pointer[DType.float32]()
    var size = Int(data.size)
    
    # Process with fast Mojo code
    process_with_simd(ptr, size)
    
    # Return to Python for I/O
    np.save("result.npy", data)
```

### 3. Handle None and Errors
```mojo
def safe_python():
    var result = some_python_function()
    
    # Check for None
    if result is None:
        print("Got None")
        return
    
    # Check truthiness
    if result:
        process(result)
```

### 4. Keep Python Objects Alive
```mojo
def lifetime_example():
    var np = Python.import_module("numpy")
    var arr = np.array([1, 2, 3])
    
    # Get pointer
    var ptr = arr.ctypes.data.unsafe_get_as_pointer[DType.int64]()
    
    # IMPORTANT: arr must stay alive while using ptr
    process(ptr)
    
    # arr still in scope here, so ptr is valid
    print(arr)  # Keep arr alive
```

### 5. Performance Considerations
- Python interop runs at Python speed
- Only Mojo-native code gets performance benefits
- Data conversion has overhead
- Batch operations when possible
- Consider copying data to Mojo types for intensive processing
