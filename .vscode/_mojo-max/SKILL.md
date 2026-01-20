---
name: mojo-max
description: Reference guide for Mojo/MAX development using the modular repository
---

# Mojo/MAX Development Skill

## Quick Reference

### Repository Locations
| Path | Description |
|------|-------------|
| `repos/modular` | Modular source repo |
| `repos/modular/mojo/` | Mojo language (stdlib, docs, examples) |
| `repos/modular/max/` | MAX framework (kernels, serve, pipelines) |
| `repos/modular/mojo/stdlib/` | Standard library source |
| `repos/modular/mojo/docs/manual/` | Language manual |

### LLM-Friendly Documentation (Always Latest)
**Use these URLs for up-to-date API docs:**
- **Index**: https://docs.modular.com/llms.txt
- **Mojo API**: https://docs.modular.com/llms-mojo.txt
- **Python API**: https://docs.modular.com/llms-python.txt  
- **Full Docs**: https://docs.modular.com/llms-full.txt
---

## Context Loading Strategy

### Level 1: Always Load (Every Session)
1. Read this SKILL.md
2. If working in modular repo, read relevant `CLAUDE.md`

### Level 2: On-Demand (When Needed)
- **Documentation**: Search/grep in `repos/modular/mojo/docs/`
- **Implementation**: Search/grep in `repos/modular/mojo/stdlib/`
- **Examples**: Browse `repos/modular/mojo/examples/`

### Level 3: Deep Dive
- Read specific source files via `view_file_outline` or `view_file`
- Check `repos/modular/mojo/proposals/` for language RFCs

---

## Essential Commands

```bash
# Using pixi (if pixi.toml present)
pixi run mojo file.mojo
pixi run mojo format ./
```

---

## Key Directory Map

```
repos/modular/
├── mojo/
│   ├── stdlib/
│   │   ├── std/           # Source: builtin, collections, memory, etc.
│   │   ├── test/          # Tests (mirror source structure)
│   │   ├── benchmarks/    # Performance benchmarks
│   │   └── docs/          # Technical docs (docstring-style-guide.md)
│   ├── docs/
│   │   ├── manual/        # User-facing manual
│   │   ├── changelog.md   # Recent changes
│   │   └── faq.md         # Common questions
│   ├── examples/          # Example code
│   └── proposals/         # Language RFC documents
├── max/
│   ├── kernels/           # High-performance Mojo GPU/CPU kernels
│   ├── serve/             # Python inference server (OpenAI-compatible)
│   ├── pipelines/         # Model architectures (Python)
│   └── nn/                # Neural network operators (Python)
└── docs/                   # General documentation
```

---

## Mojo Language Patterns

### Memory & Ownership
- Follow value semantics and ownership conventions
- Use `Reference` types with explicit lifetimes
- Prefer `AnyType` over `AnyTrivialRegType`

### Docstring Format
```mojo
fn example_function[T: Movable](value: T) -> Int:
    """Gets something from the value.
    
    Parameters:
        T: The type parameter description.
    
    Args:
        value: The input value.
    
    Returns:
        The computed integer result.
    
    Raises:
        Error: If computation fails.
    """
    ...
```

### Test Pattern
```mojo
from testing import assert_equal, assert_true

def test_my_feature():
    var result = my_function()
    assert_equal(result, expected)
```

---

## When to Use What

| Need | Action |
|------|--------|
| Latest API syntax | `read_url_content` on llms-mojo.txt |
| Stdlib implementation | `grep_search` in `repos/modular/mojo/stdlib/std/` |
| How to build/test | Read `repos/modular/mojo/CLAUDE.md` |
| Language concepts | Read `repos/modular/mojo/docs/manual/` |
| GPU kernel patterns | Browse `repos/modular/max/kernels/` |
| Recent changes | Check `repos/modular/mojo/docs/changelog.md` |

---

## Tips for Token Efficiency

1. **Don't read everything** - Use grep/find first, then read specific files
2. **Use LLM URLs** - They're curated and compressed
3. **Check CLAUDE.md first** - Contains distilled essential info
4. **Search before browsing** - `grep_search` is more efficient than reading dirs
5. **Use pixi run mojo** - It's the Mojo compiler

