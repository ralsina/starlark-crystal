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

  it "tokenizes integers" do
    lexer = Starlark::Lexer::Lexer.new("42 0 123")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([:INTEGER, :INTEGER, :INTEGER, :EOF])
    tokens[0].value.should eq("42")
    tokens[1].value.should eq("0")
    tokens[2].value.should eq("123")
  end

  it "tokenizes strings" do
    lexer = Starlark::Lexer::Lexer.new(%("hello" 'world' "escaped\\"quote"))
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([:STRING, :STRING, :STRING, :EOF])
    tokens[0].value.should eq("hello")
    tokens[1].value.should eq("world")
    tokens[2].value.should eq(%(escaped"quote))
  end

  it "tokenizes booleans and None" do
    lexer = Starlark::Lexer::Lexer.new("True False None")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([:TRUE, :FALSE, :NONE, :EOF])
  end

  it "tokenizes operators" do
    lexer = Starlark::Lexer::Lexer.new("+ - * / % // ** == != < <= > >= = += -= *= //=")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([
      :PLUS, :MINUS, :STAR, :SLASH, :PERCENT, :SLASHSLASH,
      :STARSTAR, :EQEQ, :BANGEQ, :LT, :LTE, :GT, :GTE,
      :ASSIGN, :PLUSEQ, :MINUSEQ, :STAREQ, :SLASHSLASHEQ,
      :EOF,
    ])
  end

  it "tokenizes punctuation" do
    lexer = Starlark::Lexer::Lexer.new("(){}[]:,.|")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([
      :LPAREN, :RPAREN, :LBRACE, :RBRACE, :LBRACKET, :RBRACKET,
      :COLON, :COMMA, :DOT, :PIPE, :EOF,
    ])
  end
end
