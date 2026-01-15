require "spec"
require "../src/starlark/evaluator/evaluator"

# Conformance tests for the official Starlark test suite
# Based on test_suite/starlark_test.py from bazelbuild/starlark
#
# This spec reads test files from /tmp/starlark-official/test_suite/testdata/go/
# and runs them against the Crystal implementation.

module Starlark
  module ConformanceTestHelper
    # Features not yet supported - mark tests using these as pending
    UNSUPPORTED_FEATURES = [
      "tuple assignment",    # a, b, c = 1, 2, 3
      "list assignment",     # [a, b, c] = [1, 2, 3]
      "index assignment",    # a[1] = 5
      "augmented index assignment", # x[1] += 3
      "lambda",              # lambda expressions
      "recursion",           # recursive function calls
      "kwargs dict unpacking", # **dict unpacking in function calls
      "*args/**kwargs",       # variable function arguments
      "nested function defs", # def inside def
      "list comprehension",   # [f(x) for x in seq]
    ]

    # Parse test file into chunks separated by ---
    def self.parse_test_chunks(path : String) : Array(Array(String))
      chunks = [] of Array(String)
      current_chunk = [] of String

      File.each_line(path) do |line|
        line = line.strip
        if line == "---"
          # Add current chunk if not empty
          chunks << current_chunk unless current_chunk.empty?
          current_chunk = [] of String
        else
          current_chunk << line
        end
      end

      # Add last chunk
      chunks << current_chunk unless current_chunk.empty?
      chunks
    end

    # Check if a chunk uses unsupported features
    def self.uses_unsupported_features?(chunk : Array(String)) : {Bool, String}
      code = chunk.join(" ")

      # Check for tuple assignment: a, b = ...
      if code =~ /\w+\s*,\s*\w+\s*=/
        {true, "tuple assignment"}
      # Check for list assignment: [a, b] = ...
      elsif code =~ /\[\w+.*\]\s*=/
        {true, "list assignment"}
      # Check for index assignment: x[y] = z
      elsif code =~ /\w+\[.*\]\s*[-+*\/%]?=\s*\w+/
        {true, "index assignment"}
      # Check for lambda
      elsif code.includes?("lambda")
        {true, "lambda"}
      # Check for *args or **kwargs
      elsif code =~ /def\s+\w+\([^)]*\*/
        {true, "*args/**kwargs"}
      # Check for list comprehension with function calls
      elsif code =~ /\[.*\s+for\s+\w+\s+in\s+.*\]/
        {true, "list comprehension"}
      # Check for ternary if-else: x if condition else y
      elsif code =~ /.*\sif\s+.*\selse\s+/
        {true, "ternary if-else"}
      else
        {false, ""}
      end
    end

    # Execute a test chunk and capture output
    def self.execute_chunk(chunk : Array(String)) : {String, Int32}
      evaluator = Evaluator.new

      # Register built-in assertions
      assertions = "
        def assert_eq(x, y):
          if x != y:
            print(\"assert_eq failed: %r != %r\" % (x, y))

        def assert_(cond, msg=\"assertion failed\"):
          if not cond:
            print(msg)

        def assert_ne(x, y):
          if x == y:
            print(\"assert_ne failed: %r == %r\" % (x, y))
      "
      evaluator.eval_stmt(assertions)

      output = [] of String

      # Evaluate each statement
      chunk.each do |line|
        next if line.empty? || line.starts_with?("#")
        break if line.starts_with?("###")  # Stop at error expectation marker

        begin
          result = evaluator.eval_stmt(line)
          if result && result.type != "NoneType"
            output << result.to_s
          end
        rescue ex : Exception
          return {ex.message || "Unknown error", 1}
        end
      end

      {output.join("\n"), 0}
    end
  end

  describe "Conformance Tests" do
    # Run all test files
    test_dir = "/tmp/starlark-official/test_suite/testdata/go"

    if Dir.exists?(test_dir)
      # Test files to run
      test_files = [
        "assign.star",
        "bool.star",
        "builtins.star",
        "control.star",
        "dict.star",
        "function.star",
        "int.star",
        "list.star",
        "string.star",
        "tuple.star",
      ]

      test_files.each do |filename|
        path = File.join(test_dir, filename)

        if File.exists?(path)
          describe filename do
            chunks = ConformanceTestHelper.parse_test_chunks(path)

            chunks.each_with_index do |chunk, index|
              it "chunk #{index + 1}" do
                output, exit_code = ConformanceTestHelper.execute_chunk(chunk)

                # Check for assertion failures in output
                if output.includes?("assert_eq failed") || output.includes?("assertion failed") || output.includes?("assert_ne failed")
                  fail "Assertion failed:\n#{output}"
                end

                exit_code.should eq(0)
              end
            end
          end
        else
          pending "#{filename} (not found)"
        end
      end
    else
      pending "Official test suite not found at #{test_dir}"
      puts "\nNote: Clone the official test suite with:"
      puts "  git clone https://github.com/bazelbuild/starlark /tmp/starlark-official"
    end
  end
end
