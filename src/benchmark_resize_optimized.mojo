"""Benchmark optimized resize implementations."""
from time import perf_counter_ns

# Import our optimized resize
from mojovision.resize_fast import (
    resize_fast,
    resize_fast_auto,
    InterpolationMode,
)
from mojovision.image import ImageTensor

# Import original resize for comparison
from mojovision.resize import resize as resize_original, ResizeMode

comptime UI8 = DType.uint8


fn benchmark_original_resize(
    ref src: ImageTensor[UI8],
    out_h: Int,
    out_w: Int,
    mode: Int,
    warmup: Int,
    iterations: Int,
) -> Float64:
    """Benchmark original resize function."""
    # Warmup
    for _ in range(warmup):
        var dst = resize_original(src, out_h, out_w, mode)
        _ = dst
    
    # Timed runs
    var start = perf_counter_ns()
    for _ in range(iterations):
        var dst = resize_original(src, out_h, out_w, mode)
        _ = dst
    var elapsed = perf_counter_ns() - start
    
    return Float64(elapsed) / Float64(iterations) / 1e6  # ms


fn benchmark_fast_resize(
    ref src: ImageTensor[UI8],
    out_h: Int,
    out_w: Int,
    mode: Int,
    separable: Bool,
    warmup: Int,
    iterations: Int,
) -> Float64:
    """Benchmark optimized resize function."""
    # Warmup
    for _ in range(warmup):
        var dst = resize_fast(src, out_h, out_w, mode, separable)
        _ = dst
    
    # Timed runs
    var start = perf_counter_ns()
    for _ in range(iterations):
        var dst = resize_fast(src, out_h, out_w, mode, separable)
        _ = dst
    var elapsed = perf_counter_ns() - start
    
    return Float64(elapsed) / Float64(iterations) / 1e6  # ms


fn benchmark_auto_resize(
    ref src: ImageTensor[UI8],
    out_h: Int,
    out_w: Int,
    mode: Int,
    warmup: Int,
    iterations: Int,
) -> Float64:
    """Benchmark auto-selection resize function."""
    # Warmup
    for _ in range(warmup):
        var dst = resize_fast_auto(src, out_h, out_w, mode)
        _ = dst
    
    # Timed runs
    var start = perf_counter_ns()
    for _ in range(iterations):
        var dst = resize_fast_auto(src, out_h, out_w, mode)
        _ = dst
    var elapsed = perf_counter_ns() - start
    
    return Float64(elapsed) / Float64(iterations) / 1e6  # ms


fn run_comparison_benchmark(
    name: String,
    src_h: Int, src_w: Int,
    dst_h: Int, dst_w: Int,
    warmup: Int,
    iterations: Int,
):
    """Run benchmark comparing original vs optimized implementations."""
    print("\n--- " + name + " ---")
    print("  Source: " + String(src_h) + "x" + String(src_w) + " -> " + 
          "Target: " + String(dst_h) + "x" + String(dst_w))
    
    var is_upscale = (dst_h * dst_w) > (src_h * src_w)
    print("  Direction: " + ("UPSCALE" if is_upscale else "DOWNSCALE"))
    
    # Create test image
    var src = ImageTensor[UI8].rand(src_h, src_w, 3)
    
    print("\n  NEAREST:")
    
    # Original implementation
    var t_orig_nn = benchmark_original_resize(
        src, dst_h, dst_w, ResizeMode.NEAREST, warmup, iterations
    )
    print("    Original:    " + String(t_orig_nn) + " ms")
    
    # Optimized (auto)
    var t_auto_nn = benchmark_auto_resize(
        src, dst_h, dst_w, InterpolationMode.NEAREST, warmup, iterations
    )
    print("    Auto:        " + String(t_auto_nn) + " ms")
    print("    Speedup:     " + String(t_orig_nn / t_auto_nn) + "x")
    
    print("\n  BILINEAR:")
    
    # Original
    var t_orig_bil = benchmark_original_resize(
        src, dst_h, dst_w, ResizeMode.BILINEAR, warmup, iterations
    )
    print("    Original:    " + String(t_orig_bil) + " ms")
    
    # Optimized (auto)
    var t_auto_bil = benchmark_auto_resize(
        src, dst_h, dst_w, InterpolationMode.BILINEAR, warmup, iterations
    )
    print("    Auto:        " + String(t_auto_bil) + " ms")
    print("    Speedup:     " + String(t_orig_bil / t_auto_bil) + "x")
    
    print("\n  BICUBIC:")
    
    # Original
    var t_orig_bic = benchmark_original_resize(
        src, dst_h, dst_w, ResizeMode.BICUBIC, warmup, iterations
    )
    print("    Original:    " + String(t_orig_bic) + " ms")
    
    # Optimized (auto)
    var t_auto_bic = benchmark_auto_resize(
        src, dst_h, dst_w, InterpolationMode.BICUBIC, warmup, iterations
    )
    print("    Auto:        " + String(t_auto_bic) + " ms")
    print("    Speedup:     " + String(t_orig_bic / t_auto_bic) + "x")


fn main():
    print("=" * 70)
    print("Mojo Image Resize Benchmark: Original vs Auto-Optimized")
    print("=" * 70)
    print("\nOptimizations applied:")
    print("  - Coefficient precomputation")
    print("  - Separable H/V processing (for upscale + bicubic)")
    print("  - Row parallelization (parallelize)")
    print("  - X-loop vectorization (vectorize[8])")
    print("  - Y-computation hoisting")
    print("  - SIMD cubic weights")
    print("  - Auto-selection: direct for downscale, separable for upscale+bicubic")
    
    comptime warmup = 10
    comptime iterations = 100
    
    # Test cases matching Python benchmark
    run_comparison_benchmark(
        "VGA -> Model Input",
        480, 640, 224, 224,
        warmup, iterations
    )
    
    run_comparison_benchmark(
        "1080p -> YOLO",
        1080, 1920, 640, 640,
        warmup, iterations
    )
    
    run_comparison_benchmark(
        "4K -> 1080p",
        2160, 3840, 1080, 1920,
        warmup, iterations
    )
    
    run_comparison_benchmark(
        "480p -> 1080p (Upscale)",
        480, 854, 1080, 1920,
        warmup, iterations
    )
    
    print("\n" + "=" * 70)
    print("Benchmark complete!")
    print("=" * 70)
