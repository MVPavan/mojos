---
trigger: always_on
---

# Scratchpad Rule

When verifying Mojo functionality, testing language features, or working with agent intermediate files:

1. **Use the scratchpad folder**: `scratchpad/`
2. Create this directory if it doesn't exist
3. Place all experimental/test Mojo files here (e.g., `test_ownership.mojo`, `verify_origins.mojo`)
4. Use descriptive filenames that indicate what's being tested
5. Do not Clean up temporary files after verification is complete unless the user requests otherwise

## When This Rule Applies

- Verifying Mojo language features (ownership, origins, lifetimes, etc.)
- Testing code snippets before recommending to user
- Creating intermediate files for agent analysis
- Running experimental Mojo code
- Debugging or demonstrating Mojo concepts

## Example Usage

```bash
# Create test file in scratchpad
scratchpad/test_value_semantics.mojo

# Run verification
pixi run mojo scratchpad/test_value_semantics.mojo
```