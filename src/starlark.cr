require "./starlark/*"

module Starlark
  # Main entry point for Starlark interpreter
  # Usage:
  #   evaluator = Evaluator.new
  #   evaluator.add_builtin("print", ->(args : Array(Value)) { ... })
  #   evaluator.set_global("VERSION", Value.new("1.0.0"))
  #   result = evaluator.eval_file("config.star")
end
