# Resize Benchmark - Mojo only (fast validation)
from time import perf_counter_ns
from mojovision.image import ImageTensor, UI8
from mojovision.resize import resize, ResizeMode

comptime WARMUP = 3
comptime ITERS = 10


fn benchmark_mojo(src: ImageTensor[UI8], out_h: Int, out_w: Int, mode: Int, name: String) -> Float64:
    """Benchmark Mojo resize, return avg ms."""
    # Warmup
    for _ in range(WARMUP):
        var _ = resize(src, out_h, out_w, mode)
    
    # Timed runs
    var total_ns: UInt = 0
    for _ in range(ITERS):
        var start = perf_counter_ns()
        var _ = resize(src, out_h, out_w, mode)
        total_ns += perf_counter_ns() - start
    
    var avg_ms = Float64(total_ns) / Float64(ITERS) / 1_000_000.0
    print(name, ":", avg_ms, "ms")
    return avg_ms


fn run_benchmarks(height: Int, width: Int, out_h: Int, out_w: Int):
    """Run Mojo resize benchmark suite."""
    print("\n" + "=" * 60)
    print("Image:", height, "x", width, "->", out_h, "x", out_w)
    print("=" * 60)
    
    # Create test image
    var src = ImageTensor[UI8].rand(height, width, 3)
    
    print("\n--- NEAREST ---")
    _ = benchmark_mojo(src, out_h, out_w, ResizeMode.NEAREST, "Mojo nearest")
    
    print("\n--- BILINEAR ---")
    _ = benchmark_mojo(src, out_h, out_w, ResizeMode.BILINEAR, "Mojo bilinear")
    
    print("\n--- BICUBIC ---")
    _ = benchmark_mojo(src, out_h, out_w, ResizeMode.BICUBIC, "Mojo bicubic")


fn main():
    print("MojoVision Resize Benchmark")
    print("===========================\n")
    
    # Small: 640x480 -> 224x224 (typical ML preprocessing)
    run_benchmarks(480, 640, 224, 224)
    
    # Medium: 1920x1080 -> 640x640 (YOLO input)
    run_benchmarks(1080, 1920, 640, 640)
    
    # Large: 4K -> 1080p (high-res processing)
    run_benchmarks(2160, 3840, 1080, 1920)
