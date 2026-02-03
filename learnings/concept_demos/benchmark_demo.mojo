"""Comprehensive Benchmark API Demo for Mojo.

This demo covers all major benchmark APIs:
1. Simple API: run, keep, clobber_memory, Report, Unit, Batch
2. Advanced API: Bench, Bencher, BenchConfig, BenchId
3. Throughput Metrics: BenchMetric, ThroughputMeasure
4. Quick Bench: QuickBench
5. Output Formats: Format
"""

from benchmark import (
    run,
    keep,
    clobber_memory,
    Unit,
    Report,
    Batch,
    Bench,
    Bencher,
    BenchConfig,
    BenchId,
    BenchMetric,
    ThroughputMeasure,
    QuickBench,
    Format,
)
import math


# ===----------------------------------------------------------------------=== #
# Part 1: Simple Benchmark API (run, keep, clobber_memory, Report, Unit)
# ===----------------------------------------------------------------------=== #


fn simple_math():
    """A simple function to benchmark."""
    var x = 100
    var y = 200
    var z = x * y
    # Use keep to prevent the compiler from optimizing away the calculation
    keep(z)


fn memory_heavy_work():
    """Demonstrates clobber_memory usage."""
    var buffer = List[Int](capacity=1000)
    for i in range(1000):
        buffer.append(i)

    # Force memory writes to complete (prevents reordering)
    clobber_memory()

    var sum = 0
    for i in range(len(buffer)):
        sum += buffer[i]
    keep(sum)


fn memory_heavy_work_v2():
    """Demonstrates clobber_memory usage."""
    var buffer = List[Int](capacity=1000)
    for i in range(1000):
        buffer.append(i)

    # # Force memory writes to complete (prevents reordering)
    # clobber_memory()

    var sum = 0
    for i in range(len(buffer)):
        sum += buffer[i]
    keep(sum)


fn slow_function():
    """A function that simulates work."""
    var res = 0.0
    for i in range(1000):
        res += math.sqrt(Float64(i))
    keep(res)


fn demo_simple_api() raises:
    """Demonstrates the simple benchmark API."""
    print("=" * 80)
    print("PART 1: Simple Benchmark API")
    print("=" * 80)

    # # 1.1 Basic Benchmark Run
    # print("\n--- 1.1. Basic Benchmark with run() ---")
    # var report = run[simple_math]()
    # report.print(Unit.ns)

    # # 1.2 Custom Configuration
    # print("\n--- 1.2. Custom Configuration (Warmup, Runtime Limits) ---")
    # var report_slow = run[slow_function](
    #     num_warmup_iters=5,
    #     max_iters=1_000_000,
    #     min_runtime_secs=0.1,
    #     max_runtime_secs=0.5,
    # )
    # report_slow.print(Unit.ms)

    # # 1.3 Programmatic Report Access
    # print("\n--- 1.3. Programmatic Report Access ---")
    # print("Mean time (ms):", report_slow.mean(Unit.ms))
    # print("Min time (ms):", report_slow.min(Unit.ms))
    # print("Max time (ms):", report_slow.max(Unit.ms))
    # print("Total duration (s):", report_slow.duration(Unit.s))
    # print("Total iterations:", report_slow.iters())

    # # 1.4 Different Time Units
    # print("\n--- 1.4. Different Time Units ---")
    # print("Mean time (ns):", report_slow.mean(Unit.ns))
    # print("Mean time (ms):", report_slow.mean(Unit.ms))
    # print("Mean time (s):", report_slow.mean(Unit.s))

    # 1.5 Using keep() and clobber_memory()
    print("\n--- 1.5. Compiler Optimization Prevention ---")
    print("keep(): Prevents dead code elimination")
    print("clobber_memory(): Forces memory fence (prevents reordering)")
    var memory_report = run[memory_heavy_work](
        num_warmup_iters=2,
        max_iters=100,
        min_runtime_secs=0.05,
        max_runtime_secs=0.2,
    )
    memory_report.print(Unit.ms)

    print("\nWithout clobber_memory():")
    var memory_report_v2 = run[memory_heavy_work_v2](
        num_warmup_iters=2,
        max_iters=100,
        min_runtime_secs=0.05,
        max_runtime_secs=0.2,
    )
    memory_report_v2.print(Unit.ms)

    # # 1.6 Full Report Details (shows all batches)
    # print("\n--- 1.6. Full Report with Batch Details ---")
    # report_slow.print_full(Unit.ms)


# ===----------------------------------------------------------------------=== #
# Part 2: Advanced Benchmark API (Bench, Bencher, BenchConfig, BenchId)
# ===----------------------------------------------------------------------=== #


fn vector_add(size: Int) -> Int:
    """Simple vector addition for benchmarking."""
    var a = List[Int](capacity=size)
    var b = List[Int](capacity=size)
    var c = List[Int](capacity=size)

    for i in range(size):
        a.append(i)
        b.append(i * 2)

    for i in range(size):
        c.append(a[i] + b[i])

    var sum = 0
    for i in range(len(c)):
        sum += c[i]

    return sum


fn demo_advanced_api() raises:
    """Demonstrates the advanced Bench/Bencher API."""
    print("\n" + "=" * 80)
    print("PART 2: Advanced Benchmark API (Bench, Bencher, BenchConfig)")
    print("=" * 80)

    # 2.1 Create BenchConfig
    print("\n--- 2.1. BenchConfig Setup ---")
    var config = BenchConfig(
        min_runtime_secs=0.05,
        max_runtime_secs=1,
        num_warmup_iters=3,
        max_iters=500,
        num_repetitions=3,
    )
    print("Config: min_runtime=0.05s, max_runtime=0.5s, warmup=3")

    # 2.2 Create Bench with config (using Optional)
    var bench = Bench(Optional(config^))

    # 2.3 Define benchmark function with Bencher
    @parameter
    fn bench_vector_add_1k(mut b: Bencher) raises:
        """Benchmark function using Bencher.iter."""

        @parameter
        fn work():
            var result = vector_add(Int(1e6))
            keep(result)

        b.iter[work]()

    # 2.4 Run benchmark with BenchId
    print("\n--- 2.2. Running Benchmark with Bencher ---")
    var bench_id = BenchId("vector_add", "size=1e6")
    bench.bench_function[bench_vector_add_1k](bench_id)

    # 2.5 Print results in different formats
    print("\n--- 2.3. Output Formats ---")
    print("\n[Table Format]")
    bench.config.format = Format.table
    print(bench)

    print("\n[Tabular CSV Format]")
    bench.config.format = Format.tabular
    print(bench)

    print("\n[CSV Format]")
    bench.config.format = Format.csv
    print(bench)


# ===----------------------------------------------------------------------=== #
# Part 3: Throughput Metrics (BenchMetric, ThroughputMeasure)
# ===----------------------------------------------------------------------=== #


fn matrix_multiply(size: Int) -> Int:
    """Simple matrix operation for throughput demo."""
    # var total_ops = size * size * size  # Approximate FLOPs
    var result = 0

    for i in range(size):
        for j in range(size):
            for k in range(size):
                result += i * j * k

    return result


fn demo_throughput_metrics() raises:
    """Demonstrates throughput metrics."""
    print("\n" + "=" * 80)
    print("PART 3: Throughput Metrics (BenchMetric, ThroughputMeasure)")
    print("=" * 80)

    var bench = Bench()

    # 3.1 Benchmark with throughput measures
    print("\n--- 3.1. Benchmarking with Throughput Metrics ---")

    var size = 50
    var total_elements = size * size * size
    var total_flops = total_elements  # Approximate
    var total_bytes = total_elements * 4  # Assuming 4 bytes per int

    @parameter
    fn bench_matrix(mut b: Bencher) raises:
        @parameter
        fn work():
            var result = matrix_multiply(size)
            keep(result)

        b.iter[work]()

    # Define throughput measures
    var measures = List[ThroughputMeasure]()
    measures.append(ThroughputMeasure(BenchMetric.elements, total_elements))
    measures.append(ThroughputMeasure(BenchMetric.flops, total_flops))
    measures.append(ThroughputMeasure(BenchMetric.bytes, total_bytes))

    bench.bench_function[bench_matrix](
        BenchId("matrix_multiply", "size=50"),
        measures=measures,
    )

    # 3.2 Print with metrics
    print("\n--- 3.2. Results with Throughput Metrics ---")
    bench.config.format = Format.table
    print(bench)


# ===----------------------------------------------------------------------=== #
# Part 4: QuickBench API
# ===----------------------------------------------------------------------=== #


fn add_numbers(a: Int, b: Int) -> Int:
    """Simple function for QuickBench demo."""
    return a + b


fn multiply_numbers(a: Int, b: Int, c: Int) -> Int:
    """Function with multiple args."""
    return a * b * c


fn demo_quick_bench() raises:
    """Demonstrates QuickBench for simplified benchmarking."""
    print("\n" + "=" * 80)
    print("PART 4: QuickBench API (Simplified Benchmarking)")
    print("=" * 80)

    var qb = QuickBench()

    # 4.1 Benchmark function with arguments
    print("\n--- 4.1. QuickBench with Function Arguments ---")
    qb.run[Int, Int](
        add_numbers,
        100,
        200,
        bench_id=BenchId("add_numbers", "100+200"),
    )

    # 4.2 Benchmark with multiple arguments
    qb.run[Int, Int, Int, Int](
        multiply_numbers,
        10,
        20,
        30,
        bench_id=BenchId("multiply_numbers", "10*20*30"),
    )

    # 4.3 Print results
    print("\n--- 4.2. QuickBench Results ---")
    qb.dump_report()


# ===----------------------------------------------------------------------=== #
# Main Entry Point
# ===----------------------------------------------------------------------=== #


fn main():
    """Run all benchmark demos."""
    print("\n")
    print("*" * 80)
    print("*" + " " * 78 + "*")
    print(
        "*"
        + " " * 20
        + "COMPREHENSIVE MOJO BENCHMARK API DEMO"
        + " " * 21
        + "*"
    )
    print("*" + " " * 78 + "*")
    print("*" * 80)
    print()

    try:
        # Part 1: Simple API
        # demo_simple_api()

        # # Part 2: Advanced API
        # demo_advanced_api()

        # # Part 3: Throughput Metrics
        demo_throughput_metrics()

        # # Part 4: QuickBench
        # demo_quick_bench()

        print("\n" + "=" * 80)
        print("All benchmark demos completed successfully!")
        print("=" * 80)

    except e:
        print("\n[ERROR] An error occurred during benchmarking:")
        print(e)
