"""
Comprehensive Closures Demo in Mojo

This file demonstrates the two closure types (parameter and runtime),
all capture semantics, and practical usage patterns.
"""


# =============================================================================
# PART 1: IMPLICIT CAPTURE (BORROW) - DEFAULT
# =============================================================================
fn demo_implicit_capture():
    """Default capture: immutable reference (borrow)."""
    print("\n=== 1. Implicit Capture (Borrow) ===")
    var x = 10
    var y = 20
    var li: List[Int] = [1, 2, 3]

    # Nested functions implicitly capture variables from outer scope.
    # By default, they capture by immutable reference (borrow).
    fn reader():
        print("  Inside reader: x =", x, ", y =", y)
        var list2 = li.copy()
        print("  list =", li)
        # x += 1  # ERROR: Cannot assign to captured variable
        x += 1
        # list.append(4)
        print("  Inside reader: x =", x, ", y =", y)

    reader()
    print("  Outside reader: x =", x, "(unchanged)")


# =============================================================================
# PART 2: MUTABLE CAPTURE - unified {mut}
# =============================================================================
fn demo_mutable_capture():
    """Mutable capture using 'unified {mut}'."""
    print("\n=== 2. Mutable Capture (unified {mut}) ===")
    var count = 0

    # 'unified {mut}' allows modifying captured variables
    fn incrementer() unified {mut}:
        count += 1
        print("  Inside incrementer: count =", count)

    incrementer()
    incrementer()
    incrementer()
    print("  Final count outside:", count)


# =============================================================================
# PART 3: COPY CAPTURE - unified {var varname}
# =============================================================================
fn demo_copy_capture():
    """Copy capture: snapshot at closure creation time."""
    print("\n=== 3. Copy Capture (unified {var val}) ===")
    var val = 100

    # 'unified {var val}' captures 'val' by copy (value).
    # The captured binding 'val' inside is immutable.
    fn copier() unified {var val}:
        # To modify our local copy, we must assign it to a mutable variable
        var local_val = val
        local_val += 50
        print("  Inside copier: local_val (modified copy) =", local_val)

    copier()
    print(
        "  Outside copier: val =",
        val,
        "(unchanged - was copied, not referenced)",
    )


# =============================================================================
# PART 4: PARAMETRIC CLOSURES with @parameter
# =============================================================================
fn use_parametric_closure[func: fn (Int) capturing [_] -> Int](num: Int) -> Int:
    """A function that accepts a parametric closure as a compile-time parameter.
    """
    return func(num)


fn demo_parametric_closure():
    """Parametric closures can be passed as compile-time parameters."""
    print("\n=== 4. Parametric Closures (@parameter) ===")
    var multiplier = 5

    @parameter
    fn multiply(x: Int) -> Int:
        return x * multiplier  # captures 'multiplier' by reference

    var result = use_parametric_closure[multiply](10)
    print("  multiply(10) with multiplier=5:", result)

    # Changing multiplier affects the result (reference capture)
    multiplier = 3
    result = use_parametric_closure[multiply](10)
    print("  multiply(10) with multiplier=3:", result)


# =============================================================================
# PART 5: @__copy_capture FOR PARAMETRIC CLOSURES
# =============================================================================
fn demo_copy_capture_decorator():
    """Using @__copy_capture with parametric closures."""
    print("\n=== 5. @__copy_capture Decorator ===")
    var z = 100

    @__copy_capture(z)
    @parameter
    fn get_z() -> Int:
        return z  # 'z' was copied at closure creation time

    print("  Initial z:", z)
    print("  get_z() after creation:", get_z())

    z = 999  # Modify z after closure creation
    print("  z changed to:", z)
    print("  get_z() still returns:", get_z(), "(captured copy, not reference)")


# =============================================================================
# PART 6: NESTED CLOSURES
# =============================================================================
fn demo_nested_closures():
    """Closures within closures."""
    print("\n=== 6. Nested Closures ===")
    var outer_val = 10

    fn outer_closure() unified {mut}:
        var inner_val = 5

        fn inner_closure() unified {mut}:
            # Can access both outer_val and inner_val
            outer_val += inner_val
            print("  Inner closure: outer_val now =", outer_val)

        inner_closure()
        inner_closure()

    outer_closure()
    print("  After nested closures: outer_val =", outer_val)


# =============================================================================
# PART 7: CLOSURE TYPE SIGNATURES (non-mutating)
# =============================================================================
fn execute_no_args[func: fn () capturing [_] -> None]():
    """Execute a closure with no arguments."""
    func()


fn execute_with_int[func: fn (Int) capturing [_] -> Int](x: Int) -> Int:
    """Execute a closure that takes and returns Int."""
    return func(x)


fn demo_closure_signatures():
    """Demonstrating different closure type signatures."""
    print("\n=== 7. Closure Type Signatures ===")

    # Non-capturing closures work directly as parameters
    @parameter
    fn print_hello():
        print("  Hello from parametric closure!")

    @parameter
    fn double(x: Int) -> Int:
        return x * 2

    execute_no_args[print_hello]()

    var result = execute_with_int[double](21)
    print("  double(21) =", result)

    # Capturing closure example
    var base = 10

    @parameter
    fn add_base(x: Int) -> Int:
        return x + base  # captures 'base'

    result = execute_with_int[add_base](5)
    print("  add_base(5) with base=10:", result)


# =============================================================================
# PART 8: CAPTURING MULTIPLE VARIABLES
# =============================================================================
fn demo_multiple_captures():
    """Capturing multiple variables with different semantics."""
    print("\n=== 8. Multiple Variable Captures ===")

    var a = 10
    var b = 20
    var c = 30

    # Can capture multiple variables with unified {mut}
    fn modify_all() unified {mut}:
        a += 1
        b += 2
        c += 3
        print("  Inside: a=", a, ", b=", b, ", c=", c)

    print("  Before: a=", a, ", b=", b, ", c=", c)
    modify_all()
    print("  After:  a=", a, ", b=", b, ", c=", c)


# =============================================================================
# PART 9: PRACTICAL - ACCUMULATOR PATTERN
# =============================================================================
fn demo_accumulator():
    """Practical accumulator pattern using closures."""
    print("\n=== 9. Accumulator Pattern ===")

    var total = 0
    var count = 0

    fn accumulate(value: Int) unified {mut}:
        total += value
        count += 1

    # Simulate accumulating values
    accumulate(10)
    accumulate(20)
    accumulate(30)
    accumulate(40)

    print("  Total:", total)
    print("  Count:", count)
    print("  Average:", total // count if count > 0 else 0)


# =============================================================================
# PART 10: STATE TRANSITION PATTERN
# =============================================================================
fn demo_state_pattern():
    """Using closures to maintain state."""
    print("\n=== 10. State Transition Pattern ===")

    var state = 0  # 0: idle, 1: running, 2: paused, 3: stopped

    fn get_state_name(s: Int) -> String:
        if s == 0:
            return "idle"
        elif s == 1:
            return "running"
        elif s == 2:
            return "paused"
        else:
            return "stopped"

    fn transition(new_state: Int) unified {mut}:
        print(
            "  Transition:",
            get_state_name(state),
            "->",
            get_state_name(new_state),
        )
        state = new_state

    transition(1)  # idle -> running
    transition(2)  # running -> paused
    transition(1)  # paused -> running
    transition(3)  # running -> stopped

    print("  Final state:", get_state_name(state))


# =============================================================================
# MAIN ENTRY POINT
# =============================================================================
fn main():
    print("=" * 60)
    print("COMPREHENSIVE CLOSURES DEMO")
    print("=" * 60)

    demo_implicit_capture()
    # demo_mutable_capture()
    # demo_copy_capture()
    # demo_parametric_closure()
    # demo_copy_capture_decorator()
    # demo_nested_closures()
    # demo_closure_signatures()
    # demo_multiple_captures()
    # demo_accumulator()
    # demo_state_pattern()

    print("\n" + "=" * 60)
    print("DEMO COMPLETE")
    print("=" * 60)
