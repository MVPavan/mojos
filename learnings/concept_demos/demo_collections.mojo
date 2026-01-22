from collections import List


fn demo_list_basics():
    print("\n=== Demo: List Basics ===")
    # Manual capacity avoids reallocations
    var numbers = List[Int](capacity=5)

    for i in range(5):
        numbers.append(i * 10)

    print("List created:", len(numbers), "items")
    # Access by index
    print("Item at index 2:", numbers[2])


fn demo_safe_iteration():
    print("\n=== Demo: Iteration ===")
    var data = List[String]()
    data.append("Apple")
    data.append("Banana")
    data.append("Cherry")

    # 1. Iterator loop (Safest/Cleanest)
    print("Iterating with 'for item in data':")
    for item in data:
        print("  Item:", item)  # item is a Reference, dereference it

    # 2. Index loop
    print("Iterating with index:")
    for i in range(len(data)):
        print("  Index", i, ":", data[i])


fn demo_bounds_safety():
    print("\n=== Demo: Bounds Safety ===")
    var small_list: List[Int] = [1, 2, 3]

    print("Accessing valid index 1:", small_list[1])

    print("Attempting out-of-bounds access (Safe catch)...")

    var bad_idx = 10
    if bad_idx < len(small_list):
        print(small_list[bad_idx])
    else:
        print("  [Safety Check] Index", bad_idx, "is out of bounds!")


fn main():
    demo_list_basics()
    demo_safe_iteration()
    demo_bounds_safety()
