require "spec"
require "../../../src/starlark/parser/parser"

describe Starlark::Parser do
  it "parses integer literals" do
    parser = Starlark::Parser.new("42")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::LiteralInt)
    expr.as(Starlark::AST::LiteralInt).value.should eq(42)
  end

  it "parses string literals" do
    parser = Starlark::Parser.new(%("hello"))
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::LiteralString)
    expr.as(Starlark::AST::LiteralString).value.should eq("hello")
  end

  it "parses boolean literals" do
    parser_true = Starlark::Parser.new("True")
    expr_true = parser_true.parse_expression
    expr_true.should be_a(Starlark::AST::LiteralBool)
    expr_true.as(Starlark::AST::LiteralBool).value.should eq(true)

    parser_false = Starlark::Parser.new("False")
    expr_false = parser_false.parse_expression
    expr_false.as(Starlark::AST::LiteralBool).value.should eq(false)
  end

  it "parses None" do
    parser = Starlark::Parser.new("None")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::LiteralNone)
  end

  it "parses identifiers" do
    parser = Starlark::Parser.new("foo")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::Identifier)
    expr.as(Starlark::AST::Identifier).name.should eq("foo")
  end

  it "parses binary operators" do
    parser = Starlark::Parser.new("1 + 2")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::BinaryOp)
    binary = expr.as(Starlark::AST::BinaryOp)
    binary.op.should eq(:PLUS)
    binary.left.should be_a(Starlark::AST::LiteralInt)
    binary.right.should be_a(Starlark::AST::LiteralInt)
  end

  it "respects operator precedence" do
    parser = Starlark::Parser.new("1 + 2 * 3")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::BinaryOp)
    binary = expr.as(Starlark::AST::BinaryOp)
    binary.op.should eq(:PLUS) # + is lower precedence than *
    binary.left.should be_a(Starlark::AST::LiteralInt)
    binary.right.should be_a(Starlark::AST::BinaryOp)
  end
end
