require "spec"
require "../../../src/starlark/lexer/token"

describe Starlark::Lexer::Token do
  it "creates a token with type and value" do
    token = Starlark::Lexer::Token.new(:IDENTIFIER, "foo", 1, 1)
    token.type.should eq(:IDENTIFIER)
    token.value.should eq("foo")
    token.line.should eq(1)
    token.column.should eq(1)
  end

  it "creates EOF token" do
    token = Starlark::Lexer::Token.eof(10, 20)
    token.type.should eq(:EOF)
    token.value.should be_nil
  end
end
