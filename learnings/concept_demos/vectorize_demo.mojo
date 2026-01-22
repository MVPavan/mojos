from algorithm import vectorize
from sys import simd_width_of


fn demo_basic_vectorize():
    print("\n=== Demo: Basic Vectorize (Dynamic Size) ===")

    var size = 10
    comptime simd_width = 4

    @parameter
    fn worker[width: Int](idx: Int) unified {mut}:
        print("  [SIMD Op] Processing", width, "items at index", idx)

    print("Vectorizing size", size, "with width", simd_width, "...")
    vectorize[simd_width](size, worker)


fn demo_static_size_optimization():
    print("\n=== Demo: Static Size Optimization ===")

    comptime size = 10
    comptime simd_width = 4

    @parameter
    fn worker[width: Int](idx: Int) unified {mut}:
        print("  [Optimized Op] Processing", width, "items at index", idx)

    print("Vectorizing STATIC size", size, "with width", simd_width, "...")
    vectorize[simd_width, size=size](worker)


fn demo_unrolling():
    print("\n=== Demo: Unrolling ===")

    var size = 16
    comptime simd_width = 4
    comptime unroll = 2

    @parameter
    fn worker[width: Int](idx: Int) unified {mut}:
        print("  [Unrolled Op] Processing", width, "items at index", idx)

    print(
        "Vectorizing size", size, "width", simd_width, "unroll", unroll, "..."
    )
    vectorize[simd_width, unroll_factor=unroll](size, worker)


fn main():
    demo_basic_vectorize()
    demo_static_size_optimization()
    demo_unrolling()
