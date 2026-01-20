---
trigger: always_on
---

# Mojo Development Rules

## Execution Environment
- **Pixi required**: Always use `pixi run mojo path/to/file.mojo`
- **Scratchpad**: Experimental code goes in `./scratchpad/`

## Naming Conventions
| Element | Style | Example |
|---------|-------|---------|
| Functions, variables | `snake_case` | `fn my_function()`, `var my_var` |
| Structs, traits, enums | `PascalCase` | `struct MyStruct` |
| Constants | `SCREAMING_SNAKE_CASE` | `alias MAX_SIZE = 10` |
| Modules | `flatcase` or `snake_case` | `algorithm`, `string_utils` |

## Code Style
- Prefer `fn` over `def` for strict typing
- Use `comptime` instead of `alias` [verify this is current]
- Prefer move semantics (`^` transfer) over implicit copies
- For expensive types, use explicit `var b = a.copy()`
- Format with `mojo format`

## Docstrings
Google-style, required for public APIs:
```mojo
fn add(a: Int, b: Int) -> Int:
    """Adds two integers.

    Args:
        a: First integer.
        b: Second integer.

    Returns:
        The sum of a and b.
    """
    return a + b
```

## Testing
- Test files: `test_*.mojo`
- Use `from testing import assert_equal, assert_true`

## Reference
When working with Mojo or MAX, reference `repos/modular/` for source code, docs, and examples. Prefer local docs over online.