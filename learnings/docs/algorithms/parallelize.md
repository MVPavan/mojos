# Parallelize Function in Mojo

## Overview

`parallelize` is a high-level function in `std.algorithm` that automatically distributes work across multiple CPU cores for parallel execution. It is designed for CPU-intensive tasks where operations are independent.

### Key Features
*   **True Parallelism**: Unlike Python threading (which is limited by the GIL), Mojo's `parallelize` uses all available CPU cores.
*   **Low Overhead**: Uses a thread pool to minimize the cost of spawning threads.
*   **Shared Memory**: Parallel workers can access shared memory directly (safe with Mojo's ownership system), avoiding the high cost of inter-process communication (IPC) seen in Python's `multiprocessing`.

## Key Differences: `map` vs `parallelize`

| Feature | `map` | `parallelize` |
|---------|-------|---------------|
| **Execution** | Sequential (one at a time) | Parallel (multiple cores) |
| **Use Case** | Simple iteration | CPU-intensive tasks |
| **Overhead** | Minimal | Thread creation overhead |
| **Best For** | Small/fast operations | Large computations |


## Comparison with Python

Mojo's `parallelize` is most similar to Python's **`multiprocessing.Pool`**, but significantly faster and easier to use.

| Feature | Mojo `parallelize` | Python `multiprocessing` | Python `threading` |
|---------|-------------------|-------------------------|-------------------|
| **True Parallelism** | ✅ Yes | ✅ Yes | ❌ No (GIL) |
| **Best For** | CPU-bound tasks | CPU-bound tasks | I/O-bound tasks |
| **Shared Memory** | ✅ Direct Access | ❌ IPC / Manager needed | ✅ Direct Access |
| **Overhead** | Low (Thread Pool) | High (Process creation) | Low |
| **Performance** | 🚀 Native Speed | 🐌 Slower (Pickling/IPC) | 🐢 Single-core limit |

### Visual Comparison

**Mojo `parallelize`**:
```
Worker 1: [=============] [=============]
Worker 2: [=============] [=============]
          ↑ True parallelism with shared memory
```

**Python `threading` (GIL)**:
```
Thread 1: [====GIL====]     [====GIL====]
Thread 2:     [====GIL====]     [====GIL====]
          ↑ Only ONE thread executes at a time
```

## Function Signatures

```mojo
from algorithm import parallelize

# Basic version - auto-detects CPU cores
# func signature: fn(idx: Int)
fn parallelize[func: fn(Int) capturing [origins] -> None](num_work_items: Int)

# With explicit worker count
fn parallelize[func: fn(Int) capturing [origins] -> None](
    num_work_items: Int, 
    num_workers: Int
)
```

## How It Works

1.  **Work Distribution**: Divides `num_work_items` into chunks.
2.  **Thread Pool**: Uses a pool of worker threads (defaulting to the number of logical CPU cores).
3.  **Parallel Execution**: Each worker processes its assigned range of indices.
4.  **Synchronization**: The function blocks until all workers complete.

## Usage Examples

### 1. Basic Element-wise Processing
A common pattern is processing an array of data.

```mojo
from algorithm import parallelize

var data = List[Int](capacity=1000)
# ... initialize data ...

@parameter
fn worker(idx: Int):
    # Each worker accesses a unique index, ensuring thread safety
    data[idx] = data[idx] * 2

parallelize[worker](1000)
```

### 2. Reductions (Safe Pattern)
To safely aggregate results (e.g., sum), give each worker its own storage slot to avoid race conditions.

```mojo
var num_workers = 4
var partial_sums = List[Int](capacity=num_workers)
for _ in range(num_workers):
    partial_sums.append(0)

@parameter
fn worker(worker_id: Int):
    # Perform computation and write to specific slot
    partial_sums[worker_id] = compute_heavy_sum(worker_id)
    
# Parallelize with explicit worker count
parallelize[worker](num_workers, num_workers)

# Combine results sequentially
var total = 0
for i in range(num_workers):
    total += partial_sums[i]
```

## When to Use

> [!success] Use `parallelize` when:
> *   Processing large datasets (1000+ items).
> *   Each operation is CPU-intensive (>1μs per item).
> *   Operations are independent (no data dependencies between indices).
> *   Computation time significantly exceeds thread management overhead.

> [!failure] Avoid `parallelize` when:
> *   Small datasets or very fast operations (use `map` or simple loops).
> *   Operations have complex inter-dependencies.
> *   The task is purely I/O bound (waiting for network/disk) - though it may still work, concurrency (Async) might be more appropriate.

## Safety & Best Practices

> [!important] Best Practices
> 1.  **Avoid Race Conditions**: Never write to the same memory location from multiple workers without synchronization.
>     *   *Bad*: `counter += 1` inside worker.
>     *   *Good*: `partial_counts[idx] = count` inside worker.
> 2.  **Origin Tracking**: Mojo automatically tracks captured variables. Ensure captured mutable variables are not aliased in unsafe ways.
> 3.  **Chunk Size**: If your work items are tiny, consider processing chunks of items inside the worker function to reduce overhead.
> 4.  **Memory Layout**: Use contiguous memory (List, arrays) to maximize cache efficiency across cores.
