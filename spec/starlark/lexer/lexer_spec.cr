require "spec"
require "../../../src/starlark/lexer/lexer"

describe Starlark::Lexer::Lexer do
  it "tokenizes keywords" do
    lexer = Starlark::Lexer::Lexer.new("def return if else elif for in load")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([
      :DEF, :RETURN, :IF, :ELSE, :ELIF, :FOR, :IN, :LOAD, :EOF,
    ])
  end

  it "tokenizes identifiers" do
    lexer = Starlark::Lexer::Lexer.new("foo bar_baz _private")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([:IDENTIFIER, :IDENTIFIER, :IDENTIFIER, :EOF])
    tokens[0].value.should eq("foo")
    tokens[1].value.should eq("bar_baz")
    tokens[2].value.should eq("_private")
  end
end
