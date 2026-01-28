"""
Demo: Capturing, Non-Capturing, and Escaping Closures in Mojo (VERIFIED)

THREE CLOSURE CATEGORIES:
1. Non-capturing:  fn(Int) -> Int             (top-level functions only)
2. Capturing:      fn(Int) capturing [_] -> T (@parameter nested, compile-time)
3. Escaping:       fn() escaping -> T         (runtime closures, own their state)
"""


# =============================================================================
# PART 1: NON-CAPTURING (top-level functions only)
# =============================================================================
fn execute_pure[f: fn (Int) -> Int](x: Int) -> Int:
    """Only accepts non-capturing functions (top-level)."""
    return f(x)


fn triple_toplevel(x: Int) -> Int:
    return x * 3


# =============================================================================
# PART 2: CAPTURING (@parameter closures - compile-time)
# =============================================================================
fn execute_closure[f: fn (Int) capturing [_] -> Int](x: Int) -> Int:
    """Accepts @parameter closures (always capturing type)."""
    return f(x)


# =============================================================================
# PART 3: ESCAPING (runtime closures that own their state)
# =============================================================================
fn make_multiplier(factor: Int) -> fn (Int) escaping -> Int:
    """Return a runtime closure that OWNS its captured state.

    'escaping' means the closure can outlive the function that created it.
    The captured 'factor' is COPIED into the closure's owned state.
    """

    fn multiplier(x: Int) -> Int:
        return x * factor  # captures 'factor' by copy

    return multiplier^  # transfer ownership with ^


# =============================================================================
# DEMO
# =============================================================================
fn main():
    print("=" * 65)
    print("DEMO: CAPTURING vs NON-CAPTURING vs ESCAPING CLOSURES")
    print("=" * 65)

    # -------------------------------------------------------------------------
    # Part 1: Non-capturing
    # -------------------------------------------------------------------------
    print("\n[1] NON-CAPTURING (top-level fn only):")
    var r1 = execute_pure[triple_toplevel](5)
    print("    triple_toplevel(5) =", r1, "✅")
    print("    Type: fn(Int) -> Int")

    # -------------------------------------------------------------------------
    # Part 2: Capturing (@parameter)
    # -------------------------------------------------------------------------
    print("\n[2] CAPTURING (@parameter closures):")
    var n = 4

    @parameter
    fn quad(x: Int) -> Int:
        return x * n  # captures 'n' by reference

    var r2 = execute_closure[quad](5)
    print("    quad(5) with n=4 =", r2, "✅")
    print("    Type: fn(Int) capturing [_] -> Int")
    print(
        "    Note: @parameter is ALWAYS capturing type (even without captures)"
    )

    # -------------------------------------------------------------------------
    # Part 3: Escaping (runtime closures)
    # -------------------------------------------------------------------------
    print("\n[3] ESCAPING (runtime closures):")
    var times2 = make_multiplier(2)
    var times5 = make_multiplier(5)
    print("    times2(10) =", times2(10), "✅")
    print("    times5(10) =", times5(10), "✅")
    print("    Type: fn(Int) escaping -> Int")
    print("    Can be stored, returned, and called later!")

    # -------------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------------
    print("\n" + "=" * 65)
    print("SUMMARY")
    print("=" * 65)
    print(
        """
| Type        | Keyword           | Use Case                      |
|-------------|-------------------|-------------------------------|
| Non-capture | (top-level fn)    | Pure functions, no state      |
| Capturing   | @parameter        | Compile-time, vectorize, map  |
| Escaping    | (runtime nested)  | Store/return closures at runtime |

Key differences:
- capturing = reference to outer scope, compile-time inlined
- escaping   = OWNS copied state, runtime value, can outlive creator
"""
    )
