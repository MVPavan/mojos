"""
Mojo Value Ownership - Comprehensive Test Cases
================================================
This file demonstrates all major ownership scenarios in Mojo with detailed
explanations and runnable examples.

Topics Covered:
1. Value Semantics (Copy on Assignment)
2. Immutable References (read convention - default)
3. Mutable References (mut convention)
4. Ownership Transfer (var convention + ^ sigil)
5. Argument Exclusivity
6. Copy Constructor (__copyinit__)
7. Move Constructor (__moveinit__)
8. Custom Lifecycle Methods
"""

from collections import List

# ==============================================================================
# HELPER STRUCT: ResourceOwner
# A struct that tracks its lifecycle for demonstration purposes
# ==============================================================================


struct ResourceOwner(Copyable, Stringable):
    """A struct that prints messages during lifecycle events."""

    var name: String
    var value: Int

    fn __init__(out self, name: String, value: Int):
        self.name = name
        self.value = value
        print("  [INIT] Created:", self.name, "with value", self.value)

    fn __copyinit__(out self, existing: Self):
        self.name = existing.name + "_copy"
        self.value = existing.value
        print("  [COPY] Copied:", existing.name, "->", self.name)

    fn __moveinit__(out self, deinit existing: Self):
        self.name = existing.name^
        self.name += "_moved"
        self.value = existing.value
        print("  [MOVE] Moved to:", self.name)

    fn __del__(deinit self):
        print("  [DEL] Destroyed:", self.name)

    fn __str__(self) -> String:
        return self.name + "(" + String(self.value) + ")"

    fn update(mut self, new_value: Int):
        print("  [UPDATE]", self.name, ":", self.value, "->", new_value)
        self.value = new_value


# ==============================================================================
# SCENARIO 1: VALUE SEMANTICS - Copy on Assignment
# ==============================================================================


fn demo_value_semantics():
    """
    Value Semantics: Each variable owns its own independent copy.

    When you assign one variable to another, Mojo creates a copy.
    Modifications to one variable don't affect the other.
    """
    print("\n" + "=" * 70)
    print("SCENARIO 1: VALUE SEMANTICS (Copy on Assignment)")
    print("=" * 70)

    # Simple types (trivial) - always copied
    print("\n--- 1a. Trivial Types (Int, Float, Bool) ---")
    var x: Int = 42
    var y = x  # This creates a copy (trivial types are always copied)
    y += 10
    print("  Original x:", x)  # Still 42
    print("  Modified y:", y)  # Now 52
    print("  Conclusion: x and y are independent copies")

    # Custom types with copy constructor
    print("\n--- 1b. Custom Types with Copy Constructor ---")
    var original = ResourceOwner("original", 100)
    var copied = original.copy()  # Explicit copy via .copy()
    copied.update(200)
    print("  original.value:", original.value)  # Still 100
    print("  copied.value:", copied.value)  # Now 200


# ==============================================================================
# SCENARIO 2: IMMUTABLE REFERENCES (read convention - DEFAULT)
# ==============================================================================


fn read_only_access(data: ResourceOwner):
    """
    Default argument convention: read (immutable reference).

    - Cannot modify the argument
    - No copy is made (efficient)
    - Original value is preserved
    """
    print("  Inside read_only_access:")
    print("    Received:", data.name, "with value", data.value)
    # data.update(999)  # ERROR: Cannot mutate an immutable reference
    # The value is just read, not copied


fn demo_read_convention():
    """
    Demonstrates Read Convention (Default).

    - Function receives an immutable reference
    - No copy is made - very efficient
    - Original value cannot be modified
    """
    print("\n" + "=" * 70)
    print("SCENARIO 2: IMMUTABLE REFERENCES (read convention)")
    print("=" * 70)

    var owner = ResourceOwner("reader", 42)
    print("\n--- Passing to read-only function ---")
    read_only_access(owner)  # No copy, just a reference
    print("  After function call, owner.value:", owner.value)


# ==============================================================================
# SCENARIO 3: MUTABLE REFERENCES (mut convention)
# ==============================================================================


fn mutate_value(mut data: ResourceOwner):
    """
    Mutable reference convention (mut).

    - Can read AND modify the argument
    - Changes are visible to the caller
    - No copy is made
    """
    print("  Inside mutate_value:")
    print("    Received:", data.name)
    data.update(999)  # Modifies the original!


fn demo_mut_convention():
    """
    Mutable References (mut) demonstration.

    - Function receives a mutable reference
    - Changes affect the original variable
    - Much more efficient than copy-modify-return pattern
    """
    print("\n" + "=" * 70)
    print("SCENARIO 3: MUTABLE REFERENCES (mut convention)")
    print("=" * 70)

    var owner = ResourceOwner("mutable_target", 100)
    print("\n--- Before mutation ---")
    print("  owner.value:", owner.value)

    print("\n--- Passing to mutable function ---")
    mutate_value(owner)  # Modifies owner in place

    print("\n--- After mutation ---")
    print("  owner.value:", owner.value)  # Now 999!


# ==============================================================================
# SCENARIO 4: OWNERSHIP TRANSFER (var convention + ^ sigil)
# ==============================================================================


fn take_ownership(var data: ResourceOwner):
    """
    Takes ownership using var convention.

    - Function owns the value exclusively
    - Original variable becomes uninitialized if ^ is used
    - If no ^, a copy is made
    """
    print("  Inside take_ownership:")
    print("    Now own:", data.name, "with value", data.value)
    data.update(500)
    print("    Modified to:", data.value)
    # data is destroyed when function ends (unless transferred elsewhere)


fn demo_var_without_transfer():
    """
    Demonstrates var WITHOUT transfer sigil (^).

    - A copy is made for the function
    - Original variable remains valid
    """
    print("\n" + "=" * 70)
    print("SCENARIO 4a: var CONVENTION WITHOUT TRANSFER")
    print("=" * 70)

    var owner = ResourceOwner("original_kept", 100)
    print("\n--- Passing WITHOUT ^ (copy is made) ---")
    take_ownership(owner.copy())  # Explicit copy
    print("\n--- After function call ---")
    print("  owner still exists with value:", owner.value)


fn demo_var_with_transfer():
    """
    Demonstrates var WITH transfer sigil (^).

    - Ownership is transferred to the function
    - Original variable becomes uninitialized
    - More efficient - no copy needed
    """
    print("\n" + "=" * 70)
    print("SCENARIO 4b: var CONVENTION WITH TRANSFER (^)")
    print("=" * 70)

    var owner = ResourceOwner("will_be_moved", 100)
    print("\n--- Passing WITH ^ (ownership transferred) ---")
    take_ownership(owner^)  # Transfer ownership
    # print(owner.value)  # ERROR: use of uninitialized value 'owner'
    print("\n--- After transfer: 'owner' no longer exists ---")


# ==============================================================================
# SCENARIO 5: ARGUMENT EXCLUSIVITY
# ==============================================================================


fn append_twice(mut target: String, suffix: String):
    """Demonstrates argument exclusivity rule."""
    target += suffix
    target += suffix


fn demo_argument_exclusivity():
    """
    Demonstrates Argument Exclusivity.

    - If a function receives a mutable reference, it cannot receive
      any other reference (mutable or immutable) to the same value
    - This prevents aliasing bugs and enables compiler optimizations
    """
    print("\n" + "=" * 70)
    print("SCENARIO 5: ARGUMENT EXCLUSIVITY")
    print("=" * 70)

    var text = String("Hello")

    # This would be an error if we tried to pass the same variable twice:
    # append_twice(text, text)  # ERROR: passing text mut is invalid
    #                           # since it is also passed read

    # Solution 1: Create a copy
    var suffix = String(" World")
    append_twice(text, suffix)
    print("  After append_twice:", text)

    # Solution 2: Use a separate variable for the suffix
    var name = String("Mojo")
    var greeting = String(" rocks!")
    append_twice(name, greeting)
    print("  After append_twice:", name)


# ==============================================================================
# SCENARIO 6: COPY CONSTRUCTOR (__copyinit__)
# ==============================================================================


struct DeepCopyDemo(Copyable, Stringable):
    """Demonstrates custom copy constructor for deep copies."""

    var data: List[Int]
    var name: String

    fn __init__(out self, name: String):
        self.name = name
        self.data = List[Int]()
        print("  [INIT]", name)

    fn __copyinit__(out self, existing: Self):
        # Deep copy: create new list and copy all elements
        self.name = existing.name + "_deepcopy"
        self.data = List[Int]()
        for i in range(len(existing.data)):
            self.data.append(existing.data[i])
        print("  [DEEP COPY]", existing.name, "->", self.name)

    fn __str__(self) -> String:
        return self.name

    fn add(mut self, value: Int):
        self.data.append(value)

    fn show(self):
        print("   ", self.name, "data:", end="")
        for i in range(len(self.data)):
            print("", self.data[i], end="")
        print()


fn demo_copy_constructor():
    """
    Demonstrates the Copy Constructor (__copyinit__).

    - Called when explicitly copying with .copy()
    - Should perform deep copy for value semantics
    - Heap-allocated data must be duplicated
    """
    print("\n" + "=" * 70)
    print("SCENARIO 6: COPY CONSTRUCTOR (Deep Copy)")
    print("=" * 70)

    var original = DeepCopyDemo("original")
    original.add(1)
    original.add(2)
    original.add(3)

    print("\n--- Creating deep copy ---")
    var copied = original.copy()

    print("\n--- Modifying copy only ---")
    copied.add(99)

    print("\n--- Both remain independent ---")
    original.show()  # [1, 2, 3]
    copied.show()  # [1, 2, 3, 99]


# ==============================================================================
# SCENARIO 7: MOVE CONSTRUCTOR (__moveinit__)
# ==============================================================================


fn demo_move_constructor():
    """
    Demonstrates the Move Constructor (__moveinit__).

    - Called when ownership is transferred with ^
    - Moves resources without copying
    - Original becomes uninitialized
    - Much more efficient for large types
    """
    print("\n" + "=" * 70)
    print("SCENARIO 7: MOVE CONSTRUCTOR (Ownership Transfer)")
    print("=" * 70)

    var source = ResourceOwner("source", 100)

    print("\n--- Moving to new variable ---")
    var destination = source^  # Triggers __moveinit__
    # source is now uninitialized!

    print("\n--- destination now owns the value ---")
    print("  destination:", destination.name, "=", destination.value)


# ==============================================================================
# SCENARIO 8: LIFETIME AND DESTRUCTION
# ==============================================================================


fn demo_asap_destruction():
    """
    Demonstrates ASAP Destruction (Last-Use Policy).

    - Values are destroyed immediately after their last use
    - NOT at the end of the scope (unlike C++)
    - Used to free resources as early as possible
    """
    print("\n" + "=" * 70)
    print("SCENARIO 8: ASAP DESTRUCTION (Last-Use Policy)")
    print("=" * 70)

    print("\n--- Creating 'early_drop' ---")
    var early_drop = ResourceOwner("early_drop", 1)
    print("  Using 'early_drop':", early_drop.value)
    # 'early_drop' is last used here, so it's destroyed NOW

    print("\n--- Creating 'late_drop' ---")
    var late_drop = ResourceOwner("late_drop", 2)

    print("\n--- Doing other work ---")
    print("  (early_drop should be gone by now)")

    print("  Using 'late_drop':", late_drop.value)
    # 'late_drop' lasts until here

    print("\n--- Function ending ---")


# ==============================================================================
# SCENARIO 9: PRACTICAL PATTERNS
# ==============================================================================


fn process_and_return(var data: ResourceOwner) -> ResourceOwner:
    """Takes ownership, processes, and returns."""
    data.update(data.value * 2)
    return data^  # Transfer ownership to caller


fn demo_practical_patterns():
    """
    Demonstrates Practical Ownership Patterns.

    - Take ownership, process, return (no copies)
    - Builder pattern with chained methods
    - Resource management (RAII)
    """
    print("\n" + "=" * 70)
    print("SCENARIO 9: PRACTICAL OWNERSHIP PATTERNS")
    print("=" * 70)

    print("\n--- Take-Process-Return Pattern ---")
    var original = ResourceOwner("input", 50)
    print("  Created input with value:", original.value)

    var result = process_and_return(original^)
    print("  Received result with value:", result.value)


# ==============================================================================
# MAIN: Run All Demonstrations
# ==============================================================================


fn main():
    print("\n" + "#" * 70)
    print("# MOJO VALUE OWNERSHIP - COMPREHENSIVE EXAMPLES")
    print("#" * 70)

    # Run all demos
    demo_value_semantics()
    demo_read_convention()
    demo_mut_convention()
    demo_var_without_transfer()
    demo_var_with_transfer()
    demo_argument_exclusivity()
    demo_copy_constructor()
    demo_move_constructor()
    demo_asap_destruction()
    demo_practical_patterns()

    print("\n" + "#" * 70)
    print("# ALL DEMONSTRATIONS COMPLETE")
    print("#" * 70 + "\n")
