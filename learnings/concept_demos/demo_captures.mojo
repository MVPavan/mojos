fn demo_implicit_capture():
    print("\n=== Demo: Implicit Capture (Borrow) ===")
    var x = 10
    var y = 20

    # Nested functions implicitly capture variables from outer scope.
    # By default, they capture by immutable reference (borrow).
    fn reader():
        print("  Inside reader: x =", x, ", y =", y)
        x += 1  # ERROR: Cannot assign to captured variable (implicit capture is read-only)

    reader()
    print("  Outside reader: x =", x, " (unchanged)")


fn demo_mutable_capture():
    print("\n=== Demo: Mutable Capture ===")
    var count = 0

    # To modify captured variables in a way compatible with algorithms,
    # we use 'unified {mut}'.
    fn incrementer() unified {mut}:
        count += 1
        print("  Inside incrementer: count =", count)

    incrementer()
    incrementer()
    print("  Outside incrementer: count =", count)


fn demo_copy_capture():
    print("\n=== Demo: Copy Capture ===")
    var val = 100

    # 'unified {var val}' captures 'val' by copy (value).
    # The captured binding 'val' inside is immutable.
    fn copier() unified {var val}:
        # To modify our local copy, we must assign it to a mutable variable
        var local_val = val
        local_val += 50
        print("  Inside copier: local_val =", local_val)

    copier()
    print("  Outside copier: val =", val, " (unchanged)")


fn main():
    demo_implicit_capture()
    # demo_mutable_capture()
    # demo_copy_capture()
