require "spec"
require "../../../src/starlark/evaluator/evaluator"

describe Starlark::Evaluator do
  it "evaluates integer literals" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval("42")
    result.should be_a(Starlark::Value)
    result.as_int.should eq(42)
  end

  it "evaluates string literals" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval(%("hello"))
    result.as_string.should eq("hello")
  end

  it "evaluates binary arithmetic" do
    evaluator = Starlark::Evaluator.new

    result = evaluator.eval("1 + 2")
    result.as_int.should eq(3)

    result = evaluator.eval("10 - 4")
    result.as_int.should eq(6)

    result = evaluator.eval("3 * 4")
    result.as_int.should eq(12)

    result = evaluator.eval("10 / 2")
    result.as_int.should eq(5)
  end

  it "evaluates comparison operators" do
    evaluator = Starlark::Evaluator.new

    result = evaluator.eval("1 < 2")
    result.as_bool.should eq(true)

    result = evaluator.eval("2 > 1")
    result.as_bool.should eq(true)

    result = evaluator.eval("1 == 1")
    result.as_bool.should eq(true)

    result = evaluator.eval("1 != 2")
    result.as_bool.should eq(true)
  end
end
