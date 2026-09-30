# Python conventions

Stack-specific rules for Python projects. Edit to taste; these are defaults.

## Toolchain
- Language: Python 3.12+. Type hints on all public functions.
- Env + packages: uv (`uv venv`, `uv add`, `uv run`).
- Format + lint: Ruff (`ruff format`, `ruff check`).
- Type checking: pyright (or mypy) in strict-ish mode.
- Test runner: pytest.
- Commands: `uv run pytest` / `ruff check .` / `pyright`.

## Idioms to follow
- Type-annotate signatures; let inference handle locals. Prefer precise types over `Any`.
- Dataclasses (or Pydantic at I/O boundaries) over dicts-as-structs.
- Pure functions where practical; isolate side effects.
- `pathlib.Path` over `os.path`; f-strings over `.format`/`%`.
- Comprehensions for simple maps/filters; a real loop when logic gets non-trivial.
- Context managers for resource lifecycle. EAFP over LBYL where it reads cleaner.
- pytest: plain `assert`, fixtures for setup, `parametrize` for cases.

## Things to avoid
- Mutable default arguments (`def f(x=[])`).
- Bare `except:` and broad `except Exception` that swallows. Catch what you handle.
- `*`-imports and deep relative imports.
- Reaching for a framework/lib where the stdlib is fine (see universal section 4).
- Logic in `__init__.py`.

## Project layout (typical)
- `src/<pkg>/`: package code (src layout)
- `tests/`: mirrors package structure
- `pyproject.toml`: single source for deps, ruff, pytest, tool config
