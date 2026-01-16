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

  it "parses assignment statements" do
    parser = Starlark::Parser.new("x = 42")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::Assign)
    assign = stmt.as(Starlark::AST::Assign)
    assign.target.should be_a(Starlark::AST::Identifier)
    assign.target.as(Starlark::AST::Identifier).name.should eq("x")
    assign.value.should be_a(Starlark::AST::LiteralInt)
  end

  it "parses if statements" do
    parser = Starlark::Parser.new("if True: pass")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::If)
  end

  it "parses for statements" do
    parser = Starlark::Parser.new("for x in [1, 2, 3]: pass")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::For)
  end

  it "parses return statements" do
    parser = Starlark::Parser.new("return 42")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::Return)
  end

  it "parses def statements" do
    parser = Starlark::Parser.new("def foo(): return 1")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::Def)
  end

  it "parses tuple unpacking from tuple literal" do
    parser = Starlark::Parser.new("(a, b) = (1, 2)")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::TupleAssign)
  end

  it "parses tuple unpacking from list literal" do
    parser = Starlark::Parser.new("(x, y, z) = [10, 20, 30]")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::TupleAssign)
  end

  it "parses implicit tuple unpacking without parentheses" do
    parser = Starlark::Parser.new("a, b, c = 1, 2, 3")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::TupleAssign)
    stmt.as(Starlark::AST::TupleAssign).targets.elements.size.should eq(3)
  end

  it "parses implicit tuple unpacking with expressions" do
    parser = Starlark::Parser.new("x, y = 10 + 5, 3 * 4")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::TupleAssign)
  end

  it "parses list unpacking" do
    parser = Starlark::Parser.new("[a, b, c] = [1, 2, 3]")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::TupleAssign)
    stmt.as(Starlark::AST::TupleAssign).targets.elements.size.should eq(3)
  end

  it "parses list unpacking from tuple" do
    parser = Starlark::Parser.new("[x, y] = (10, 20)")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::TupleAssign)
  end

  it "parses break statement" do
    parser = Starlark::Parser.new("break")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::Break)
  end

  it "parses continue statement" do
    parser = Starlark::Parser.new("continue")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::Continue)
  end

  it "parses ternary if-else expression" do
    parser = Starlark::Parser.new("1 if True else 0")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::IfExpr)
  end
end
