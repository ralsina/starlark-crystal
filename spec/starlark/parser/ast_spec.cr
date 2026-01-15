require "spec"
require "../../../src/starlark/parser/ast.cr"

describe Starlark::AST::Node do
  it "creates a literal node" do
    node = Starlark::AST::LiteralInt.new(42)
    node.value.should eq(42)
  end

  it "creates an identifier node" do
    node = Starlark::AST::Identifier.new("foo")
    node.name.should eq("foo")
  end
end
