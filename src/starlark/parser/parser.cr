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
      parse_not
    end

    def parse_statement : AST::Stmt
      token = current_token

      if token.nil?
        raise "Unexpected end of input"
      end

      case token.type
      when :IDENTIFIER
        parse_assignment_or_expr_stmt
      when :IF
        parse_if
      when :FOR
        parse_for
      when :RETURN
        parse_return
      when :DEF
        parse_def
      when :PASS
        advance
        AST::Pass.new
      else
        expr = parse_expression
        AST::ExprStmt.new(expr)
      end
    end

    # Precedence levels (higher = tighter binding)
    PRECEDENCE = {
      :OR => 1,
      :AND => 2,
      :NOTIN => 3, :IN => 3,
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
      # Handle unary plus/minus (but NOT 'not' - that has lower precedence)
      tok = current_token
      if !tok.nil? && (tok.type == :PLUS || tok.type == :MINUS)
        advance
        expr = parse_unary
        AST::UnaryOp.new(tok.type, expr)
      else
        # Handle primary expressions with postfix
        primary = parse_primary
        parse_postfix(primary)
      end
    end

    private def parse_not : AST::Expr
      # Handle 'not' operator (lower precedence than comparisons)
      tok = current_token
      if !tok.nil? && tok.type == :NOT
        advance
        expr = parse_not  # right-associative
        AST::UnaryOp.new(:NOT, expr)
      else
        parse_binary_op(3)  # Start at comparison precedence
      end
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
        # Check if this is a tuple or parenthesized expression
        expr = parse_expression

        tok = current_token
        if !tok.nil? && tok.type == :COMMA
          # This is a tuple
          elements = [expr]
          while !tok.nil? && tok.type == :COMMA
            advance
            elements << parse_expression
            tok = current_token
          end
          expect(:RPAREN)
          AST::TupleLiteral.new(elements)
        else
          # This is a parenthesized expression or potential function call
          expect(:RPAREN)
          expr
        end
      when :LBRACKET
        advance
        elements = [] of AST::Expr
        tok = current_token
        if tok.nil? || tok.type != :RBRACKET
          elements << parse_expression
          comma_tok = current_token
          while !comma_tok.nil? && comma_tok.type == :COMMA
            advance
            elements << parse_expression
            comma_tok = current_token
          end
        end
        expect(:RBRACKET)
        AST::List.new(elements)
      when :LBRACE
        advance
        entries = [] of Tuple(AST::Expr, AST::Expr)
        tok = current_token
        if tok.nil? || tok.type != :RBRACE
          # Parse key: value
          key = parse_expression
          expect(:COLON)
          value = parse_expression
          entries << {key, value}

          # Parse additional entries
          comma_tok = current_token
          while !comma_tok.nil? && comma_tok.type == :COMMA
            advance
            key = parse_expression
            expect(:COLON)
            value = parse_expression
            entries << {key, value}
            comma_tok = current_token
          end
        end
        expect(:RBRACE)
        AST::Dict.new(entries)
      else
        raise "Unexpected token in expression: #{token.type}"
      end
    end

    private def parse_postfix(left : AST::Expr) : AST::Expr
      while @pos < @tokens.size
        tok = current_token
        break if tok.nil?

        case tok.type
        when :LPAREN
          # Function call
          advance
          args = [] of AST::Expr

          tok = current_token
          if !tok.nil? && tok.type != :RPAREN
            args << parse_expression
            tok = current_token
            while !tok.nil? && tok.type == :COMMA
              advance
              args << parse_expression
              tok = current_token
            end
          end

          expect(:RPAREN)
          left = AST::Call.new(left, args)
        when :LBRACKET
          # Index or slice
          advance

          # Check if this is a slice (contains :)
          has_colon = false

          # Scan ahead to see if there's a colon
          scan_pos = @pos
          while scan_pos < @tokens.size
            scan_tok = @tokens[scan_pos]
            if scan_tok.type == :COLON
              has_colon = true
              break
            elsif scan_tok.type == :RBRACKET
              break
            end
            scan_pos += 1
          end

          if has_colon
            # Parse slice
            start_expr = nil
            end_expr = nil

            # Check if there's an expression before :
            tok = current_token
            if !tok.nil? && tok.type != :COLON && tok.type != :RBRACKET
              start_expr = parse_expression
            end

            # Expect colon or end
            tok = current_token
            if !tok.nil? && tok.type == :COLON
              advance

              # Check if there's an expression after :
              tok = current_token
              if !tok.nil? && tok.type != :RBRACKET
                end_expr = parse_expression
              end
            end

            expect(:RBRACKET)
            left = AST::Slice.new(left, start_expr, end_expr)
          else
            # Regular index
            index_expr = parse_expression
            expect(:RBRACKET)
            left = AST::Index.new(left, index_expr)
          end
        else
          break
        end
      end

      left
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

    private def parse_assignment_or_expr_stmt : AST::Stmt
      # Look ahead to see if this is an assignment
      save_pos = @pos

      # Try to parse just a primary expression (identifier) for assignment target
      begin
        left = parse_primary
        if left.is_a?(AST::Identifier)
          tok = current_token
          if !tok.nil? && (tok.type == :ASSIGN || augmented_assign_op?)
            # Assignment
            op = tok.type
            advance
            value = parse_expression

            if op == :ASSIGN
              return AST::Assign.new(left, value)
            else
              # Augmented assignment: x += 1 -> x = x + 1
              inner_op = augmented_to_binary(op)
              binary_expr = AST::BinaryOp.new(left, inner_op, value)
              return AST::Assign.new(left, binary_expr)
            end
          end
        end
      rescue
        # Not a valid assignment target, fall through to expression statement
      end

      # Expression statement
      @pos = save_pos
      expr = parse_expression
      AST::ExprStmt.new(expr)
    end

    private def augmented_assign_op? : Bool
      tok = current_token
      return false if tok.nil?
      {:PLUSEQ, :MINUSEQ, :STAREQ, :SLASHEQ, :PERCENTEQ, :SLASHSLASHEQ}.includes?(tok.type)
    end

    private def augmented_to_binary(augmented_op : Symbol) : Symbol
      case augmented_op
      when :PLUSEQ       then :PLUS
      when :MINUSEQ      then :MINUS
      when :STAREQ       then :STAR
      when :SLASHEQ      then :SLASH
      when :PERCENTEQ    then :PERCENT
      when :SLASHSLASHEQ then :SLASHSLASH
      else                    raise "Unknown augmented operator: #{augmented_op}"
      end
    end

    private def parse_if : AST::If
      expect(:IF)
      condition = parse_expression
      expect(:COLON)
      then_block = parse_block

      elif_blocks = [] of Tuple(AST::Expr, Array(AST::Stmt))
      tok = current_token
      while !tok.nil? && tok.type == :ELIF
        advance
        elif_cond = parse_expression
        expect(:COLON)
        elif_body = parse_block
        elif_blocks << {elif_cond, elif_body}
        tok = current_token
      end

      else_block = nil
      tok = current_token
      if !tok.nil? && tok.type == :ELSE
        advance
        expect(:COLON)
        else_block = parse_block
      end

      AST::If.new(condition, then_block, elif_blocks, else_block)
    end

    private def parse_for : AST::For
      expect(:FOR)
      tok = current_token
      if tok.nil?
        raise "Expected identifier after 'for'"
      end
      var_name = token_value(tok)
      expect(:IDENTIFIER)
      expect(:IN)
      iterable = parse_expression
      expect(:COLON)
      body = parse_block

      AST::For.new(AST::Identifier.new(var_name), iterable, body)
    end

    private def parse_return : AST::Return
      expect(:RETURN)
      value = nil
      # Check if next token can start an expression
      tok = current_token
      if !tok.nil? && tok.type != :EOF && can_start_expression?
        value = parse_expression
      end
      AST::Return.new(value)
    end

    private def can_start_expression? : Bool
      tok = current_token
      return false if tok.nil?
      {:INTEGER, :STRING, :TRUE, :FALSE, :NONE, :IDENTIFIER, :LPAREN, :LBRACKET, :PLUS, :MINUS, :STAR}.includes?(tok.type)
    end

    private def parse_def : AST::Def
      expect(:DEF)
      tok = current_token
      if tok.nil?
        raise "Expected identifier after 'def'"
      end
      name = token_value(tok)
      expect(:IDENTIFIER)
      expect(:LPAREN)

      params = [] of String
      tok = current_token
      if !tok.nil? && tok.type != :RPAREN
        params << token_value(tok)
        expect(:IDENTIFIER)
        tok = current_token
        while !tok.nil? && tok.type == :COMMA
          advance
          tok = current_token
          if tok.nil?
            raise "Expected identifier after comma"
          end
          params << token_value(tok)
          expect(:IDENTIFIER)
          tok = current_token
        end
      end

      expect(:RPAREN)
      expect(:COLON)
      body = parse_block

      AST::Def.new(name, params, body)
    end

    private def parse_block : Array(AST::Stmt)
      # Simple block parsing: one statement
      # Full indentation-based parsing is deferred
      stmts = [] of AST::Stmt
      stmts << parse_statement
      stmts
    end
  end
end
