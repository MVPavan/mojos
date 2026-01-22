from algorithm import parallelize
from algorithm.functional import parallelism_level
from time import perf_counter_ns


fn main():
    print("=== Parallelize Demo ===\n")
    print(
        "PL : ",
        parallelism_level(),
    )
    # Example 1: Basic parallel processing
    print("1. Basic Parallel Processing")
    print("-" * 40)

    comptime size = 20
    var data = List[Int](capacity=size)
    for i in range(size):
        data.append(i)

    # Worker function that processes each index
    @parameter
    fn worker(idx: Int):
        # Simulate some work by squaring the value
        data[idx] = data[idx] ** 2

    # Execute in parallel - automatically uses available CPU cores
    parallelize[worker](size)

    print("Results (first 10):")
    for i in range(10):
        print("  data[", i, "] =", data[i])

    # Example 2: Controlling number of workers
    print("\n2. Parallel Sum with Worker Control")
    print("-" * 40)

    comptime array_size = 1000
    var numbers = List[Int](capacity=array_size)
    for i in range(array_size):
        numbers.append(i + 1)

    # Partial sums for each worker (using OwnedPointer for thread-safe storage)
    var num_workers = 4
    var partial_sums = List[Int](capacity=num_workers)
    for _ in range(num_workers):
        partial_sums.append(0)

    @parameter
    fn sum_worker(worker_id: Int):
        # Each worker processes a chunk of the array
        var chunk_size = array_size // num_workers
        var start = worker_id * chunk_size
        var end = (
            start + chunk_size if worker_id < num_workers - 1 else array_size
        )

        var local_sum = 0
        for i in range(start, end):
            local_sum += numbers[i]

        partial_sums[worker_id] = local_sum
        print(
            "  Worker",
            worker_id,
            "processed indices",
            start,
            "to",
            end - 1,
            "| Partial sum:",
            local_sum,
        )

    # Run with specific number of workers
    parallelize[sum_worker](num_workers, num_workers)

    # Combine partial sums
    var total_sum = 0
    for i in range(num_workers):
        total_sum += partial_sums[i]

    print("\nTotal sum:", total_sum)
    print("Expected:", (array_size * (array_size + 1)) // 2)

    # Example 3: Performance comparison
    print("\n3. Performance: Sequential vs Parallel")
    print("-" * 40)

    comptime work_size = 10000
    var work_data = List[Float64](capacity=work_size)
    for i in range(work_size):
        work_data.append(Float64(i))

    # Sequential version
    var start_time = perf_counter_ns()
    for i in range(work_size):
        # Simulate expensive computation
        work_data[i] = work_data[i] ** 2 + work_data[i] ** 0.5
    var sequential_time = perf_counter_ns() - start_time

    # Reset data
    for i in range(work_size):
        work_data[i] = Float64(i)

    # Parallel version
    @parameter
    fn parallel_worker(idx: Int):
        work_data[idx] = work_data[idx] ** 2 + work_data[idx] ** 0.5

    start_time = perf_counter_ns()
    parallelize[parallel_worker](work_size)
    var parallel_time = perf_counter_ns() - start_time

    print("Sequential time:", sequential_time, "ns")
    print("Parallel time:  ", parallel_time, "ns")
    if parallel_time > 0:
        print(
            "Speedup:        ",
            Float64(sequential_time) / Float64(parallel_time),
            "x",
        )

    print("\n=== Demo Complete ===")
