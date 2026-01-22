from algorithm import map
from memory import OwnedPointer


fn main():
    print("--- Map Demo with Safe Pointers ---")

    # OwnedPointer is for single values, so we use List for collections
    # List IS the safe alternative for array-like storage in Mojo
    comptime size = 10
    var data = List[Int](capacity=size)

    # Initialize with some values
    for i in range(size):
        data.append(i * 10)

    # Demonstrating OwnedPointer for a single value
    var counter = OwnedPointer[Int](0)

    # Define the worker function
    @parameter
    fn worker(idx: Int):
        var val = data[idx]
        print("Worker processing index:", idx, "| Value:", val)
        data[idx] = val + 1
        # OwnedPointer dereference with []
        counter[] += 1

    # Invoke map
    print("\nRunning map...")
    map[worker](size)

    print("\nProcessed", counter[], "elements")
    print("\nVerifying results:")
    for i in range(len(data)):
        print("Index:", i, "| New Value:", data[i])

    # No manual cleanup needed!
    # - List automatically frees its memory
    # - OwnedPointer automatically frees its allocation
