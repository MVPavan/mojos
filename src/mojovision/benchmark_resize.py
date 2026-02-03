#!/usr/bin/env python3
"""Benchmark PIL/OpenCV resize for comparison with MojoVision."""
import gc
import time

import cv2
import numpy as np
from PIL import Image

WARMUP = 10
ITERS = 20


def benchmark(name, fn):
    """Run benchmark and return avg ms."""
    # Force GC before benchmark
    gc.collect()

    # Warmup
    for _ in range(WARMUP):
        _ = fn()

    # Timed runs
    times = []
    for _ in range(ITERS):
        start = time.perf_counter()
        _ = fn()
        times.append((time.perf_counter() - start) * 1000)

    # Use median to avoid outliers
    times.sort()
    median = times[ITERS // 2]
    avg = sum(times) / len(times)
    print(f"{name}: {median:.4f} ms (median), {avg:.4f} ms (avg)")
    return median


def run_benchmarks(h, w, out_h, out_w):
    """Benchmark all resize modes."""
    print(f"\n{'='*60}")
    print(f"Image: {h} x {w} -> {out_h} x {out_w}")
    print(f"{'='*60}")

    # Create random image - ensure contiguous
    img_np = np.ascontiguousarray(np.random.randint(0, 255, (h, w, 3), dtype=np.uint8))
    img_pil = Image.fromarray(img_np)

    # Run each mode separately to avoid interference
    print("\n--- NEAREST ---")
    benchmark(
        "PIL nearest", lambda: img_pil.resize((out_w, out_h), Image.Resampling.NEAREST)
    )
    benchmark(
        "OpenCV nearest",
        lambda: cv2.resize(img_np, (out_w, out_h), interpolation=cv2.INTER_NEAREST),
    )

    print("\n--- BILINEAR ---")
    benchmark(
        "PIL bilinear",
        lambda: img_pil.resize((out_w, out_h), Image.Resampling.BILINEAR),
    )
    benchmark(
        "OpenCV bilinear",
        lambda: cv2.resize(img_np, (out_w, out_h), interpolation=cv2.INTER_LINEAR),
    )

    print("\n--- BICUBIC ---")
    benchmark(
        "PIL bicubic", lambda: img_pil.resize((out_w, out_h), Image.Resampling.BICUBIC)
    )
    benchmark(
        "OpenCV bicubic",
        lambda: cv2.resize(img_np, (out_w, out_h), interpolation=cv2.INTER_CUBIC),
    )


if __name__ == "__main__":
    print("Python Resize Benchmark (PIL + OpenCV)")
    print("=" * 40)

    # Same test cases as Mojo
    run_benchmarks(480, 640, 224, 224)
    run_benchmarks(1080, 1920, 640, 640)
    run_benchmarks(2160, 3840, 1080, 1920)
