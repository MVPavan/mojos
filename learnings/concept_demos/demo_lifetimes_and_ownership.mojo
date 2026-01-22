from time import sleep

# ===----------------------------------------------------------------------=== #
# Helper Types
# ===----------------------------------------------------------------------=== #


struct Tracker(ImplicitlyCopyable):
    var name: String

    fn __init__(out self, name: String):
        self.name = name
        print("[LIFECYCLE] + Init:", self.name)

    fn __copyinit__(out self, other: Self):
        self.name = other.name + "_copy"
        print("[LIFECYCLE] * Copy:", self.name, "from", other.name)

    fn __moveinit__(out self, deinit other: Self):
        self.name = other.name + "_moved"
        print("[LIFECYCLE] > Move:", self.name, "from", other.name)

    fn __del__(deinit self):
        print("[LIFECYCLE] - Destroy:", self.name)


struct MoveOnly:
    var data: Int

    fn __init__(out self, data: Int):
        self.data = data
        print("[MoveOnly] Init:", self.data)

    fn __moveinit__(out self, deinit other: Self):
        self.data = other.data
        print("[MoveOnly] Moved:", self.data)

    # No __copyinit__ means this CANNOT be copied.


# ===----------------------------------------------------------------------=== #
# Demos
# ===----------------------------------------------------------------------=== #


fn demo_lifecycle_scope():
    print("\n=== Demo: Scope & Destruction ===")
    print("Entering scope...")
    var t = Tracker("ScopedItem")
    print("Doing work...")
    # t is destroyed at end of scope (or last use if eager)
    print("Exiting scope...")


fn demo_move_semantics():
    print("\n=== Demo: Move Semantics (^) ===")
    var original = Tracker("Original")

    print("Moving 'Original' to 'NewOwner'...")
    # The transfer operator ^ terminates 'original's lifetime immediately here
    # and passes ownership to 'new_owner'.
    var new_owner = original^

    # print(original.name) # ERROR: 'original' is uninitialized here!
    print("NewOwner is alive:", new_owner.name)


fn demo_copy_semantics():
    print("\n=== Demo: Copy Semantics ===")
    var source = Tracker("Source")

    print("Copying 'Source' to 'Replica'...")
    var replica = source  # Implicit copy if __copyinit__ exists

    print("Source still alive:", source.name)
    print("Replica is alive:", replica.name)


fn arg_borrow(x: Tracker):
    print("  [Borrow] Reading:", x.name)


fn arg_mutate(var x: Tracker):
    print("  [Mutate] Modifying copy:", x.name)
    x.name += "_edited"


fn arg_consume(var x: Tracker):
    print("  [Consume] Taking ownership of:", x.name)
    # x is destroyed at end of this function


fn demo_argument_passing():
    print("\n=== Demo: Argument Passing ===")
    var item = Tracker("Item")

    # 1. Borrowed (Default) - Read Only
    arg_borrow(item)

    # 2. Inout - Mutable Reference
    arg_mutate(item)
    print("  [Main] Back from modify:", item.name)

    # 3. Owned - Transfer Ownership
    arg_consume(item^)
    # item is gone now


fn demo_move_only_type():
    print("\n=== Demo: Move-Only Types ===")
    var m = MoveOnly(42)

    fn take_it(var x: MoveOnly):
        print("  Taking MoveOnly:", x.data)

    # take_it(m) # ERROR: Cannot copy!
    take_it(m^)  # OK: Explicit move
    print("  Move complete.")


fn main():
    demo_lifecycle_scope()
    demo_move_semantics()
    demo_copy_semantics()
    demo_argument_passing()
    demo_move_only_type()
