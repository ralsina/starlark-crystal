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

  it "evaluates assignment statements" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_stmt("x = 42")
    evaluator.get_global("x").as_int.should eq(42)
  end

  it "evaluates if statements" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_stmt("if True: x = 1")
    evaluator.get_global("x").as_int.should eq(1)
  end

  it "evaluates for loops over lists" do
    evaluator = Starlark::Evaluator.new
    # Test iterating over a list and setting a variable
    evaluator.eval_stmt("for x in [1, 2, 3]: y = x")
    # After the loop, y should be the last value (3)
    evaluator.get_global("y").as_int.should eq(3)
  end

  # Task 11: Lists and Dicts
  it "evaluates dict literals" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval(%({"a": 1, "b": 2}))
    result.type.should eq("dict")
    dict = result.as_dict
    dict.size.should eq(2)
  end

  it "evaluates empty dict" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval("{}")
    result.type.should eq("dict")
    result.as_dict.empty?.should be_true
  end

  it "evaluates list indexing" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_stmt("x = [1, 2, 3]")
    result = evaluator.eval("x[0]")
    result.as_int.should eq(1)
    result = evaluator.eval("x[1]")
    result.as_int.should eq(2)
    result = evaluator.eval("x[2]")
    result.as_int.should eq(3)
  end

  it "evaluates dict indexing" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_stmt(%(d = {"a": 1, "b": 2}))
    result = evaluator.eval(%(d["a"]))
    result.as_int.should eq(1)
    result = evaluator.eval(%(d["b"]))
    result.as_int.should eq(2)
  end

  it "evaluates negative list indexing" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_stmt("x = [1, 2, 3]")
    result = evaluator.eval("x[-1]")
    result.as_int.should eq(3)
    result = evaluator.eval("x[-2]")
    result.as_int.should eq(2)
  end

  it "evaluates list slicing" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_stmt("x = [1, 2, 3, 4, 5]")
    result = evaluator.eval("x[1:3]")
    result.type.should eq("list")
    result.as_list.map(&.as_int).should eq([2, 3])
  end

  it "evaluates list slicing with start" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_stmt("x = [1, 2, 3, 4, 5]")
    result = evaluator.eval("x[2:]")
    result.type.should eq("list")
    result.as_list.map(&.as_int).should eq([3, 4, 5])
  end

  it "evaluates list slicing with end" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_stmt("x = [1, 2, 3, 4, 5]")
    result = evaluator.eval("x[:3]")
    result.type.should eq("list")
    result.as_list.map(&.as_int).should eq([1, 2, 3])
  end
end
