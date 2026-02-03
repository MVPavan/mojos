# ImageTensor - Core image abstraction with zero-copy support
from memory import UnsafePointer, memcpy, memset_zero, alloc
from random import rand

comptime UI8 = DType.uint8
comptime F32 = DType.float32


struct ImageTensor[dtype: DType = UI8](Movable):
    """Efficient image tensor with SIMD-friendly memory layout."""
    # Proper pointer type using MutExternalOrigin (builtin) 
    var data: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin]
    var height: Int
    var width: Int
    var channels: Int
    var _owned: Bool

    # --- Constructors ---
    fn __init__(out self, height: Int, width: Int, channels: Int = 3):
        """Allocate new image tensor."""
        self.height = height
        self.width = width
        self.channels = channels
        self.data = alloc[Scalar[Self.dtype]](height * width * channels)
        memset_zero(self.data, height * width * channels)
        self._owned = True

    fn __init__(out self, data: UnsafePointer[Scalar[Self.dtype], MutExternalOrigin], height: Int, width: Int, channels: Int):
        """Wrap existing data (zero-copy)."""
        self.data = data
        self.height = height
        self.width = width
        self.channels = channels
        self._owned = False

    fn __moveinit__(out self, deinit other: Self):
        self.data = other.data
        self.height = other.height
        self.width = other.width
        self.channels = other.channels
        self._owned = other._owned

    fn __del__(deinit self):
        if self._owned:
            self.data.free()

    # --- Factory Methods ---
    @staticmethod
    fn rand(height: Int, width: Int, channels: Int = 3) -> Self:
        """Create image with random values."""
        var img = Self(height, width, channels)
        rand(img.data, img.num_elements())
        return img^

    # --- Properties ---
    @always_inline
    fn num_elements(self) -> Int:
        return self.height * self.width * self.channels

    @always_inline
    fn stride_y(self) -> Int:
        """Row stride in elements."""
        return self.width * self.channels

    @always_inline
    fn stride_x(self) -> Int:
        """Column stride in elements."""
        return self.channels

    # --- Indexing (HWC layout) ---
    @always_inline
    fn _idx(self, y: Int, x: Int, c: Int) -> Int:
        return y * self.stride_y() + x * self.stride_x() + c

    @always_inline
    fn __getitem__(self, y: Int, x: Int, c: Int) -> Scalar[Self.dtype]:
        return self.data[self._idx(y, x, c)]

    @always_inline
    fn __setitem__(mut self, y: Int, x: Int, c: Int, val: Scalar[Self.dtype]):
        self.data[self._idx(y, x, c)] = val

    # --- SIMD Operations ---
    @always_inline
    fn load[width: Int](self, y: Int, x: Int, c: Int) -> SIMD[Self.dtype, width]:
        return self.data.load[width=width](self._idx(y, x, c))

    @always_inline
    fn store[width: Int](mut self, y: Int, x: Int, c: Int, val: SIMD[Self.dtype, width]):
        self.data.store[width=width](self._idx(y, x, c), val)

    @always_inline
    fn load_pixel[width: Int](self, y: Int, x: Int) -> SIMD[Self.dtype, width]:
        """Load `width` channels starting at (y, x, 0)."""
        return self.data.load[width=width](self._idx(y, x, 0))

    @always_inline
    fn store_pixel[width: Int](mut self, y: Int, x: Int, val: SIMD[Self.dtype, width]):
        """Store `width` channels starting at (y, x, 0)."""
        self.data.store[width=width](self._idx(y, x, 0), val)

    # --- Utility ---
    fn shape(self) -> String:
        return String(self.height) + "x" + String(self.width) + "x" + String(self.channels)

    fn copy(self) -> Self:
        """Deep copy."""
        var img = Self(self.height, self.width, self.channels)
        memcpy(dest=img.data, src=self.data, count=self.num_elements())
        return img^
