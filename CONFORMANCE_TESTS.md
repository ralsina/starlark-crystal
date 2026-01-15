# Conformance Test Results

Tested against the official Starlark test suite from bazelbuild/starlark.

## Test Summary

- **Total Test Chunks**: 245
- **Passing**: 0
- **Errors**: 245 (tests that fail due to missing features or bugs)
- **Pending**: 0

## Unsupported Features

The following features are not yet implemented in the Crystal Starlark interpreter:

### 1. Tuple/List Assignment
- `a, b, c = 1, 2, 3`
- `[a, b, c] = [1, 2, 3]`
- `(a, b) = (1, 2)`
- Nested unpacking: `(a, [b, c]) = (1, [2, 3])`

### 2. Index Assignment
- `list[1] = 5`
- `dict[key] = value`
- Augmented index assignment: `x[1] += 3`

### 3. Ternary If-Else
- `value if condition else default`

### 4. Lambda Expressions
- `lambda x: x + 1`
- Y combinator patterns

### 5. Variable Function Arguments
- `*args` for variable positional arguments
- `**kwargs` for variable keyword arguments
- `def f(*args, **kwargs)`

### 6. Kwargs Dict Unpacking
- `f(**dict(x=1))`

### 7. List Comprehensions with Function Calls
- `[f(x) for x in seq]`
- The parser can handle simple comprehensions like `[x for x in seq]`

## Test Files

| File | Chunks | Status |
|------|--------|--------|
| assign.star | 20 | Multiple unsupported features |
| bool.star | 7 | Ternary if-else not supported |
| builtins.star | 18 | Various missing builtins |
| control.star | 9 | Nested functions and other issues |
| dict.star | 20 | Index assignment, dict literals |
| function.star | 14 | *args/**kwargs, recursion, lambda |
| int.star | 8 | Bitwise operators, int builtin |
| list.star | 22 | List comprehensions with calls |
| string.star | 81 | String formatting, slicing |
| tuple.star | 3 | Tuple literals |

## Known Issues

### Parser Issues
1. **Assignment parsing**: Only simple identifier assignment (`x = value`) is supported
2. **Ternary expressions**: `x if condition else y` not parsed
3. **Tuple literals**: `(1, 2, 3)` not parsed as tuple

### Evaluator Issues
1. **String formatting**: `%` operator for strings not implemented
2. **Advanced slicing**: Negative indices and extended slicing not working
3. **Built-in functions**: Many built-ins from the official spec are missing

### Missing Built-in Functions
- `all()`, `any()`
- `chr()`, `ord()`
- `enumerate()`, `zip()`
- `filter()`, `map()`, `reduce()`
- `max()`, `min()`
- `reversed()`, `sorted()`
- `setattr()`, `getattr()`, `hasattr()`
- `type()`
- `hash()`

### Missing Operators
- Bitwise: `&`, `|`, `^`, `~`, `<<`, `>>`
- Matrix multiplication: `@`
- In-place operators on non-identifier targets

## Running the Tests

```bash
# Clone the official test suite
git clone https://github.com/bazelbuild/starlark /tmp/starlark-official

# Run conformance tests
crystal spec spec/conformance_test_spec.cr
```

## Next Steps

To improve conformance, implement features in this order:

1. **Tuple literals** - Low hanging fruit
2. **Index assignment** - Important for dict/list manipulation
3. **Ternary if-else** - Common pattern
4. **Variable function arguments** - Required for many tests
5. **String formatting** - heavily used
6. **List/tuple assignment** - Complex but important

## Notes

- The current implementation has 64 passing internal unit tests
- Basic functionality works (literals, expressions, statements, functions, closures)
- The interpreter can evaluate simple Starlark programs successfully
- Focus should be on parser support for missing syntax first, then evaluator/runtime features
