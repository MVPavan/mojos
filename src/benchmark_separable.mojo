"""Benchmark separable vs direct bilinear resize implementations."""
from time import perf_counter_ns

from mojovision.resize_fast import (
    resize_fast,
    resize_fast_auto,
    InterpolationMode,
    ImageResizer,
)
from mojovision.image import ImageTensor

comptime UI8 = DType.uint8


fn benchmark_bilinear_direct(
    ref src: ImageTensor[UI8],
    ref dst: ImageTensor[UI8],
    warmup: Int,
    iterations: Int,
) -> Float64:
    """Benchmark direct bilinear."""
    # Warmup
    for _ in range(warmup):
        ImageResizer.resize_bilinear_direct(
            src.data, dst.data,
            src.height, src.width, dst.height, dst.width, src.channels
        )
    
    var start = perf_counter_ns()
    for _ in range(iterations):
        ImageResizer.resize_bilinear_direct(
            src.data, dst.data,
            src.height, src.width, dst.height, dst.width, src.channels
        )
    var elapsed = perf_counter_ns() - start
    
    return Float64(elapsed) / Float64(iterations) / 1e6


fn benchmark_bilinear_separable(
    ref src: ImageTensor[UI8],
    ref dst: ImageTensor[UI8],
    warmup: Int,
    iterations: Int,
) -> Float64:
    """Benchmark separable bilinear (float32 intermediate)."""
    # Warmup
    for _ in range(warmup):
        ImageResizer.resize_bilinear_separable(
            src.data, dst.data,
            src.height, src.width, dst.height, dst.width, src.channels
        )
    
    var start = perf_counter_ns()
    for _ in range(iterations):
        ImageResizer.resize_bilinear_separable(
            src.data, dst.data,
            src.height, src.width, dst.height, dst.width, src.channels
        )
    var elapsed = perf_counter_ns() - start
    
    return Float64(elapsed) / Float64(iterations) / 1e6


fn benchmark_bilinear_simd(
    ref src: ImageTensor[UI8],
    ref dst: ImageTensor[UI8],
    warmup: Int,
    iterations: Int,
) -> Float64:
    """Benchmark SIMD gather/scatter bilinear."""
    # Warmup
    for _ in range(warmup):
        ImageResizer.resize_bilinear_simd(
            src.data, dst.data,
            src.height, src.width, dst.height, dst.width, src.channels
        )
    
    var start = perf_counter_ns()
    for _ in range(iterations):
        ImageResizer.resize_bilinear_simd(
            src.data, dst.data,
            src.height, src.width, dst.height, dst.width, src.channels
        )
    var elapsed = perf_counter_ns() - start
    
    return Float64(elapsed) / Float64(iterations) / 1e6


fn benchmark_bilinear_separable_fixed(
    ref src: ImageTensor[UI8],
    ref dst: ImageTensor[UI8],
    warmup: Int,
    iterations: Int,
) -> Float64:
    """Benchmark separable bilinear with Q8.8 fixed-point (int16 intermediate)."""
    # Warmup
    for _ in range(warmup):
        ImageResizer.resize_bilinear_separable_fixed(
            src.data, dst.data,
            src.height, src.width, dst.height, dst.width, src.channels
        )
    
    var start = perf_counter_ns()
    for _ in range(iterations):
        ImageResizer.resize_bilinear_separable_fixed(
            src.data, dst.data,
            src.height, src.width, dst.height, dst.width, src.channels
        )
    var elapsed = perf_counter_ns() - start
    
    return Float64(elapsed) / Float64(iterations) / 1e6


fn compute_max_diff(ref a: ImageTensor[UI8], ref b: ImageTensor[UI8]) -> Int:
    """Compute maximum absolute difference between two images."""
    var max_diff = 0
    var size = a.height * a.width * a.channels
    for i in range(size):
        var diff = Int(a.data[i]) - Int(b.data[i])
        if diff < 0:
            diff = -diff
        if diff > max_diff:
            max_diff = diff
    return max_diff


fn compute_mse(ref a: ImageTensor[UI8], ref b: ImageTensor[UI8]) -> Float64:
    """Compute mean squared error between two images."""
    var sum_sq = 0.0
    var size = a.height * a.width * a.channels
    for i in range(size):
        var diff = Float64(Int(a.data[i]) - Int(b.data[i]))
        sum_sq += diff * diff
    return sum_sq / Float64(size)


fn run_benchmark(
    name: String,
    src_h: Int, src_w: Int,
    dst_h: Int, dst_w: Int,
    warmup: Int,
    iterations: Int,
):
    """Compare bilinear implementations."""
    print("\n--- " + name + " ---")
    print("  Source: " + String(src_h) + "x" + String(src_w) + 
          " -> Target: " + String(dst_h) + "x" + String(dst_w))
    
    var channels = 3
    var src = ImageTensor[UI8].rand(src_h, src_w, channels)
    var dst_direct = ImageTensor[UI8](dst_h, dst_w, channels)
    var dst_fixed = ImageTensor[UI8](dst_h, dst_w, channels)
    
    # Direct
    var t_direct = benchmark_bilinear_direct(src, dst_direct, warmup, iterations)
    print("  Direct:     " + String(t_direct) + " ms")
    
    # Separable (float32)
    var dst_sep = ImageTensor[UI8](dst_h, dst_w, channels)
    var t_sep = benchmark_bilinear_separable(src, dst_sep, warmup, iterations)
    print("  Separable:  " + String(t_sep) + " ms (float32 intermediate)")
    print("    vs Direct: " + String(t_direct / t_sep) + "x")
    
    # SIMD gather/scatter
    var dst_simd = ImageTensor[UI8](dst_h, dst_w, channels)
    var t_simd = benchmark_bilinear_simd(src, dst_simd, warmup, iterations)
    print("  SIMD:       " + String(t_simd) + " ms")
    print("    vs Direct: " + String(t_direct / t_simd) + "x")
    
    # Fixed-point separable (int16 intermediate)
    var t_fixed = benchmark_bilinear_separable_fixed(src, dst_fixed, warmup, iterations)
    print("  Fixed-pt:   " + String(t_fixed) + " ms (int16 intermediate)")
    print("    vs Direct: " + String(t_direct / t_fixed) + "x")
    print("    vs Sep-F32: " + String(t_sep / t_fixed) + "x")
    
    # Correctness check: compare fixed-point output to direct
    var max_diff = compute_max_diff(dst_direct, dst_fixed)
    var mse = compute_mse(dst_direct, dst_fixed)
    print("  Quality (Fixed vs Direct): max_diff=" + String(max_diff) + ", MSE=" + String(mse))
    
    # Intermediate buffer size info
    var tmp_size_f32 = src_h * dst_w * channels * 4  # float32
    var tmp_size_i16 = src_h * dst_w * channels * 2  # int16
    print("  Buffer F32: " + String(tmp_size_f32 / 1024) + " KB")
    print("  Buffer I16: " + String(tmp_size_i16 / 1024) + " KB")


fn main():
    print("=" * 70)
    print("Bilinear Resize: Direct vs Separable vs SIMD")
    print("=" * 70)
    
    comptime warmup = 10
    comptime iterations = 50
    
    run_benchmark("VGA -> 224", 480, 640, 224, 224, warmup, iterations)
    run_benchmark("1080p -> YOLO", 1080, 1920, 640, 640, warmup, iterations)
    run_benchmark("4K -> 1080p", 2160, 3840, 1080, 1920, warmup, iterations)
    run_benchmark("480p -> 1080p (Upscale)", 480, 854, 1080, 1920, warmup, iterations)
    
    print("\n" + "=" * 70)
    print("Benchmark complete!")
