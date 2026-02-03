# NumPy/Python interop utilities for ImageTensor
from python import Python, PythonObject
from memory import memcpy, UnsafePointer
from .image import ImageTensor, UI8


fn to_numpy(img: ImageTensor[UI8]) -> PythonObject:
    """Convert ImageTensor to NumPy array (HWC, uint8)."""
    try:
        var np = Python.import_module("numpy")
        var shape = PythonObject([img.height, img.width, img.channels])
        var arr = np.empty(shape, dtype=np.uint8)
        var ptr = int(arr.__array_interface__["data"][0].to_float64())
        memcpy(UnsafePointer[UInt8](address=ptr), img.data.bitcast[UInt8](), img.num_elements())
        return arr^
    except e:
        print("to_numpy error:", e)
        return PythonObject()


fn from_numpy(arr: PythonObject) raises -> ImageTensor[UI8]:
    """Create ImageTensor from NumPy array (HWC, uint8)."""
    var np = Python.import_module("numpy")
    var h = int(arr.shape[0])
    var w = int(arr.shape[1])
    var c = int(arr.shape[2]) if arr.ndim > 2 else 1
    var img = ImageTensor[UI8](h, w, c)
    var arr_c = np.ascontiguousarray(arr, dtype=np.uint8)
    var ptr = int(arr_c.__array_interface__["data"][0].to_float64())
    memcpy(img.data.bitcast[UInt8](), UnsafePointer[UInt8](address=ptr), img.num_elements())
    _ = arr_c
    return img^
