require "spec"
require "../../../src/starlark/types/value"

describe Starlark::Value do
  it "creates None value" do
    val = Starlark::Value.none
    val.type.should eq("NoneType")
    val.truth.should eq(false)
  end

  it "creates boolean values" do
    val = Starlark::Value.new(true)
    val.type.should eq("bool")
    val.truth.should eq(true)

    val_false = Starlark::Value.new(false)
    val_false.truth.should eq(false)
  end

  it "creates integer values" do
    val = Starlark::Value.new(42_i64)
    val.type.should eq("int")
    val.truth.should eq(true)
  end

  it "creates string values" do
    val = Starlark::Value.new("hello")
    val.type.should eq("string")
    val.truth.should eq(true)

    empty = Starlark::Value.new("")
    empty.truth.should eq(false)
  end
end
