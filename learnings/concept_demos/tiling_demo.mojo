from algorithm.functional import (
    tile,
    unswitch,
    tile_and_unswitch,
    tile_middle_unswitch_boundaries,
)
from sys import simd_width_of


fn example_tile():
    print("\n=== Tile Example ===")

    # We want to process 10 items
    # We want to tile with size 4
    # Expected:
    #   Tile 4 (items 0-3)
    #   Tile 4 (items 4-7)
    #   Tile 1 (item 8) - residue handled by cleanup
    #   Tile 1 (item 9) - residue

    @parameter
    fn print_tile[width: Int](offset: Int):
        print("Processing tile of width", width, "at offset", offset)

    # tile[func, tile_size_list](offset, upperbound)
    # NOTE: For static tile, you MUST provide a fallback size (usually 1) to handle remainders.
    tile[print_tile, VariadicList(4, 2)](10, 20)


fn example_unswitch():
    print("\n=== Unswitch Example ===")

    # We have a function with a boolean flag
    # unswitch will generate two versions of the code: one where flag is True, one where False
    # and pick the right one at runtime, removing the 'if' check from inside the hot path if it were in a loop

    @parameter
    fn complex_op[is_fast_mode: Bool]():
        @parameter
        if is_fast_mode:
            print("Running FAST mode (no checks)")
        else:
            print("Running SLOW mode (safe checks)")

    var dynamic_condition = True
    print("Condition is True:")
    unswitch[complex_op](dynamic_condition)

    dynamic_condition = False
    print("Condition is False:")
    unswitch[complex_op](dynamic_condition)


fn example_tile_and_unswitch():
    print("\n=== Tile and Unswitch Example ===")
    # Identical to tile, but passes 'True' to the tile function for the "main" body
    # and 'False' for the cleanup/residue.
    # Useful for SIMD pointers where main loop is aligned (Safe=True) and end is not (Safe=False)

    @parameter
    fn worker[width: Int, is_main_loop: Bool](offset: Int, limit: Int):
        print(
            "Offset:",
            offset,
            "| Width:",
            width,
            "| MainLoop optimized:",
            is_main_loop,
            "| limit:",
            limit,
        )

    # tile_and_unswitch[worker, tile_sizes](start, end)
    tile_and_unswitch[worker, VariadicList(4, 2, 1)](0, 11)


fn example_tile_middle():
    print("\n=== Tile Middle Unswitch Boundaries Example ===")
    print("Scenario: Image Width 10, Tile Size 4")
    print("Expectation: Left(0-4 checks), Middle(4-8 fast), Right(8-10 checks)")

    @parameter
    fn conv_worker[width: Int, is_left: Bool, is_right: Bool](offset: Int):
        if is_left:
            print(
                "  [LEFT EDGE]  Safe processing inputs at",
                offset,
                "width",
                width,
            )
        elif is_right:
            print(
                "  [RIGHT EDGE] Safe processing inputs at",
                offset,
                "width",
                width,
            )
        else:
            print(
                "  [MIDDLE]     FAST processing inputs at",
                offset,
                "width",
                width,
            )

    # tile_middle_unswitch_boundaries[func, tile_size, total_size]()
    tile_middle_unswitch_boundaries[conv_worker, 4, 10]()


fn example_tile_middle_explicit():
    print("\n=== Tile Middle Unswitch Boundaries (Explicit) Example ===")

    # Signature: work_fn[width: Int, is_boundary: Bool](offset)
    @parameter
    fn manual_worker[width: Int, is_boundary: Bool](offset: Int):
        if is_boundary:
            print("  [BOUNDARY] Checking edges at", offset, "width", width)
        else:
            print("  [CENTER]   Fast processing at", offset, "width", width)

    # tile_middle_unswitch_boundaries[func, middle_tiles, left_tile, right_tile](lb_start, lb_end, rb_start, rb_end)
    tile_middle_unswitch_boundaries[manual_worker, VariadicList(4, 2), 1, 1](
        0, 1, 8, 10
    )


fn main():
    # example_tile()
    # example_unswitch()
    # example_tile_and_unswitch()
    example_tile_middle()
    example_tile_middle_explicit()
