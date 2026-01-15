# Starlark Crystal

A [Starlark](https://github.com/google/starlark-go) interpreter written in Crystal.

Starlark is a configuration language designed for safety and determinism, used by tools like Bazel, Buck, and Please.

## Features

- Complete Starlark syntax support
- Pure Crystal implementation (no Python dependency)
- Type-safe runtime values
- Lexical closures
- Value freezing (immutability after evaluation)
- Crystal integration API for embedding

## Installation

Add this to your `shard.yml`:

```yaml
dependencies:
  starlark:
    git: https://github.com/yourusername/starlark.git
```

Then run:

```bash
shards install
```

## Building

```bash
shards build
```

## Usage

### Basic Evaluation

```crystal
require "starlark"

evaluator = Starlark::Evaluator.new

# Evaluate expressions
result = evaluator.eval("1 + 2 * 3")
puts result.as_int  # => 7

# Execute statements
evaluator.eval_stmt("x = 42")
puts evaluator.get_global("x").as_int  # => 42
```

### Setting Globals

```crystal
evaluator.set_global("VERSION", Starlark::Value.new("1.0.0"))
evaluator.set_global("DEBUG", Starlark::Value.new(true))
```

### Custom Built-in Functions

```crystal
# Register a custom function
square_func = ->(args : Array(Starlark::Value)) {
  value = args[0].as_int
  Starlark::Value.new(value * value)
}
evaluator.register_builtin("square", square_func)

# Use it from Starlark
result = evaluator.eval("square(5)")
puts result.as_int  # => 25
```

### Evaluating Files

Create a `.star` file:

```python
# config.star
name = "MyApp"
version = "1.0.0"

def get_version():
    return version + "-beta"

settings = {
    "port": 8080,
    "host": "localhost",
}
```

Evaluate it:

```crystal
evaluator.eval_file("config.star")

puts evaluator.get_global("name").as_string           # => "MyApp"
puts evaluator.get_global("settings").as_dict          # => dict
```

## Supported Features

### Literals
- Integers: `42`, `0`, `-123`
- Strings: `"hello"`, `'world'`
- Booleans: `True`, `False`
- None: `None`

### Operators
- Arithmetic: `+`, `-`, `*`, `/`, `%`, `//`, `**`
- Comparison: `==`, `!=`, `<`, `<=`, `>`, `>=`
- Logical: `and`, `or`, `not`
- Assignment: `=`, `+=`, `-=`, `*=`, `/=`, `//=`

### Data Structures
- Lists: `[1, 2, 3]`, `list("abc")`
- Dicts: `{"key": "value"}`, `dict([("a", 1)])`
- Tuples: `(1, 2, 3)`, `tuple([1, 2])`
- Indexing: `list[0]`, `dict["key"]`
- Slicing: `list[1:3]`, `string[0:5]`

### Control Flow
- Conditionals: `if/elif/else`
- Loops: `for x in iterable:`
- Functions: `def foo(a, b): return a + b`
- Returns: `return value`

### Built-in Functions
- `len(x)` - Length of strings, lists, dicts
- `range(n)` - Generate list of integers
- `str(x)` - Convert to string
- `int(x)` - Convert to integer
- `bool(x)` - Convert to boolean
- `list(x)` - Create list
- `dict(x)` - Create dict
- `tuple(x)` - Create tuple

## Testing

Run the test suite:

```bash
crystal spec
```

## Demo

A demo program is included to showcase the interpreter's capabilities:

```bash
crystal run demo.cr
```

## Examples

### Function with Closures

```crystal
evaluator.eval_stmt("
def make_adder(n):
    return def adder(x):
        return x + n

add5 = make_adder(5)
")
result = evaluator.eval("add5(3)")
puts result.as_int  # => 8
```

### List Operations

```crystal
evaluator.eval_stmt("numbers = [1, 2, 3, 4, 5]")
evaluator.eval_stmt("for n in numbers: total = total + n")
puts evaluator.get_global("total").as_int  # => 15
```

### Conditionals

```crystal
evaluator.eval_stmt("
if score >= 90:
    grade = 'A'
elif score >= 80:
    grade = 'B'
else:
    grade = 'C'
")
```

## License

MIT

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
