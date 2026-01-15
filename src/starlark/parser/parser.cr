require "../lexer/lexer"
require "./ast"

module Starlark
  class Parser
    @tokens : Array(Lexer::Token)
    @pos : Int32

    def initialize(source : String)
      @tokens = Lexer::Lexer.new(source).tokenize
      @pos = 0
    end

    def parse_expression : AST::Expr
      parse_binary_op(0)
    end

    # Precedence levels (higher = tighter binding)
    PRECEDENCE = {
      :OR => 1,
      :AND => 2,
      :EQEQ => 3, :BANGEQ => 3, :LT => 3, :LTE => 3, :GT => 3, :GTE => 3,
      :PLUS => 4, :MINUS => 4,
      :STAR => 5, :SLASH => 5, :PERCENT => 5, :SLASHSLASH => 5,
      :STARSTAR => 6,
    }

    private def parse_binary_op(min_precedence : Int32) : AST::Expr
      left = parse_unary

      while @pos < @tokens.size
        op_token = current_token
        break if op_token.nil?

        precedence = PRECEDENCE[op_token.type]?

        break if precedence.nil? || precedence < min_precedence

        advance
        right = parse_binary_op(precedence + 1)
        left = AST::BinaryOp.new(left, op_token.type, right)
      end

      left
    end

    private def parse_unary : AST::Expr
      # For now, just handle primary expressions
      parse_primary
    end

    private def parse_primary : AST::Expr
      token = current_token

      if token.nil?
        raise "Unexpected end of input"
      end

      case token.type
      when :INTEGER
        advance
        AST::LiteralInt.new(token_value(token).to_i64)
      when :STRING
        advance
        AST::LiteralString.new(token_value(token))
      when :TRUE
        advance
        AST::LiteralBool.new(true)
      when :FALSE
        advance
        AST::LiteralBool.new(false)
      when :NONE
        advance
        AST::LiteralNone.new
      when :IDENTIFIER
        advance
        AST::Identifier.new(token_value(token))
      when :LPAREN
        advance
        expr = parse_expression
        expect(:RPAREN)
        expr
      else
        raise "Unexpected token in expression: #{token.type}"
      end
    end

    private def token_value(token : Lexer::Token) : String
      value = token.value
      if value.nil?
        raise "Token must have a value"
      end
      value
    end

    private def expect(type : Symbol)
      token = current_token
      if token.nil?
        raise "Expected #{type}, got end of input"
      elsif token.type == type
        advance
      else
        raise "Expected #{type}, got #{token.type}"
      end
    end

    private def current_token : Lexer::Token?
      @tokens[@pos]?
    end

    private def advance
      @pos += 1
    end
  end
end
