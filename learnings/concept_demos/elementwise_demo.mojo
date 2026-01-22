from algorithm import elementwise
from sys import simd_width_of

# Mocking Index/IndexList if not strictly available or just using what works
# Assuming standard library is available.
# The internal code used `from utils.index import Index, IndexList`.
# In user code, often `Index` is just a helper or we pass `Int` for 1D.
# Let's try to mimic the internal structure to be safe since we are in the repo context.
# But for a robust example, I will use what I saw in 'test_elementwise.mojo':
# from utils.index import IndexList, Index

from utils.index import IndexList, Index


fn main():
    # 1. Define the shape of our iteration space (e.g., a 2D image or matrix)
    # Let's say we have a 10x10 grid.
    var shape = Index(10, 10)
    print("Shape:", shape)

    # 2. Define the SIMD width we want to optimize for.
    # For float32 on many systems this is 4, 8, or 16.
    # We'll pick 4 to make the print output readable.
    alias target_simd_width = 4
    print("Target SIMD Width:", target_simd_width)
    print("---------------------------------------------------")

    # 3. Define the function to apply element-wise.
    # This function receives the starting index of the SIMD vector.
    @parameter
    fn my_kernel[
        width: Int, rank: Int, alignment: Int
    ](idx_list: IndexList[rank]):
        # 'width' is the actual width processed in this call.
        # It will be 'target_simd_width' for most calls, but smaller at the boundaries.

        # 'idx_list' is the multi-dimensional index.
        # idx_list[0] is the row, idx_list[1] is the column (start).

        # We perform the operation for 'width' elements starting at 'idx_list'.
        var row = idx_list[0]
        var col_start = idx_list[1]

        print(
            "Kernel called | Width:",
            width,
            "| Row:",
            row,
            "| Col:",
            col_start,
            "->",
            col_start + width,
        )

    # 4. Invoke elementwise
    # It will automatically loop over the shape and dispatch to 'my_kernel'
    try:
        elementwise[my_kernel, target_simd_width](shape)
    except e:
        print("Error:", e)
