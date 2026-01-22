from algorithm import map
from collections import List


fn demo_map_basic():
    print("\n=== Demo: Map Basic ===")

    var size = 5
    var data = List[Int](capacity=size)
    for i in range(size):
        data.append(i * 10)

    print("Initial Data:")
    for i in range(len(data)):
        print("  ", data[i])

    # Map allows you to apply a function across a range [0, size)
    # The function 'worker' captures 'data' from the context.
    @parameter
    fn worker(idx: Int):
        # Read
        var val = data[idx]
        # Modify
        data[idx] = val + 1
        print("  [Worker] Index", idx, "processed.")

    print("\nRunning map[worker](", size, ")...")
    map[worker](size)

    print("\nVerifying results (Expect +1):")
    for i in range(len(data)):
        print("  Index", i, ":", data[i])


fn main():
    demo_map_basic()
