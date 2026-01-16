require "./token"

module Starlark
  module Lexer
    KEYWORDS = {
      "and" => :AND, "as" => :AS, "assert" => :ASSERT,
      "break" => :BREAK, "class" => :CLASS, "continue" => :CONTINUE,
      "def" => :DEF, "del" => :DEL, "elif" => :ELIF,
      "else" => :ELSE, "for" => :FOR, "if" => :IF,
      "in" => :IN, "lambda" => :LAMBDA, "load" => :LOAD,
      "not" => :NOT, "or" => :OR, "pass" => :PASS,
      "return" => :RETURN, "while" => :WHILE,
      "True" => :TRUE, "False" => :FALSE, "None" => :NONE,
      "not in" => :NOTIN,
    }

    class Lexer
      @source : String
      @pos : Int32
      @line : Int32
      @column : Int32

      def initialize(@source)
        @pos = 0
        @line = 1
        @column = 1
      end

      def tokenize : Array(Token)
        tokens = [] of Token

        while @pos < @source.size
          char = current_char

          if char.whitespace?
            consume_whitespace
          elsif char.ascii_letter? || char == '_'
            tokens << read_identifier_or_keyword
          elsif char.ascii_number?
            tokens << read_number
          elsif char == '"' || char == '\''
            tokens << read_string
          else
            tokens << read_operator_or_punctuation
          end
        end

        tokens << Token.eof(@line, @column)
        tokens
      end

      private def read_identifier_or_keyword : Token
        start_line = @line
        start_column = @column

        chars = [] of Char
        while @pos < @source.size && (current_char.ascii_alphanumeric? || current_char == '_')
          chars << current_char
          advance
        end

        value = chars.join

        # Special case: check for "not in"
        if value == "not"
          # Save current position
          saved_pos = @pos
          saved_line = @line
          saved_column = @column

          # Skip whitespace
          while @pos < @source.size && current_char.whitespace?
            if current_char == '\n'
              @line += 1
              @column = 1
            else
              @column += 1
            end
            @pos += 1
          end

          # Check if next token is "in"
          next_chars = [] of Char
          while @pos < @source.size && (current_char.ascii_alphanumeric? || current_char == '_')
            next_chars << current_char
            advance
          end
          next_value = next_chars.join

          if next_value == "in"
            # Consume both "not" and "in", return NOTIN token
            # Position is already advanced past "in"
            Token.new(:NOTIN, "not in", start_line, start_column)
          else
            # Restore position and continue normally
            @pos = saved_pos
            @line = saved_line
            @column = saved_column
            type = KEYWORDS[value]?
            type ||= :IDENTIFIER
            Token.new(type, value, start_line, start_column)
          end
        else
          type = KEYWORDS[value]?
          type ||= :IDENTIFIER
          Token.new(type, value, start_line, start_column)
        end
      end

      private def consume_whitespace
        while @pos < @source.size && current_char.whitespace?
          if current_char == '\n'
            @line += 1
            @column = 1
          else
            @column += 1
          end
          @pos += 1
        end
      end

      private def read_number : Token
        start_line = @line
        start_column = @column

        value = String.build do |io|
          while @pos < @source.size && current_char.ascii_number?
            io << current_char
            advance
          end
        end

        Token.new(:INTEGER, value, start_line, start_column)
      end

      private def read_string : Token
        start_line = @line
        start_column = @column
        quote = current_char
        advance # consume opening quote

        value = String.build do |io|
          while @pos < @source.size && current_char != quote
            if current_char == '\\'
              advance # consume backslash
              if @pos < @source.size
                io << current_char
                advance
              end
            else
              io << current_char
              advance
            end
          end
        end

        advance # consume closing quote
        Token.new(:STRING, value, start_line, start_column)
      end

      private def current_char : Char
        @source[@pos]
      end

      private def advance
        @column += 1
        @pos += 1
      end

      private def peek_char : Char?
        @source[@pos + 1]?
      end

      private def read_operator_or_punctuation : Token
        start_line = @line
        start_column = @column

        case current_char
        when '+'
          advance
          if current_char == '='
            advance
            Token.new(:PLUSEQ, "+=", start_line, start_column)
          else
            Token.new(:PLUS, "+", start_line, start_column)
          end
        when '-'
          advance
          if current_char == '='
            advance
            Token.new(:MINUSEQ, "-=", start_line, start_column)
          else
            Token.new(:MINUS, "-", start_line, start_column)
          end
        when '*'
          advance
          if current_char == '*'
            advance
            Token.new(:STARSTAR, "**", start_line, start_column)
          elsif current_char == '='
            advance
            Token.new(:STAREQ, "*=", start_line, start_column)
          else
            Token.new(:STAR, "*", start_line, start_column)
          end
        when '/'
          advance
          if current_char == '/'
            advance
            if current_char == '='
              advance
              Token.new(:SLASHSLASHEQ, "//=", start_line, start_column)
            else
              Token.new(:SLASHSLASH, "//", start_line, start_column)
            end
          elsif current_char == '='
            advance
            Token.new(:SLASHEQ, "/=", start_line, start_column)
          else
            Token.new(:SLASH, "/", start_line, start_column)
          end
        when '%'
          advance
          if current_char == '='
            advance
            Token.new(:PERCENTEQ, "%=", start_line, start_column)
          else
            Token.new(:PERCENT, "%", start_line, start_column)
          end
        when '='
          advance
          if current_char == '='
            advance
            Token.new(:EQEQ, "==", start_line, start_column)
          else
            Token.new(:ASSIGN, "=", start_line, start_column)
          end
        when '!'
          advance
          if current_char == '='
            advance
            Token.new(:BANGEQ, "!=", start_line, start_column)
          else
            raise "Unexpected character: !"
          end
        when '<'
          advance
          if current_char == '='
            advance
            Token.new(:LTE, "<=", start_line, start_column)
          else
            Token.new(:LT, "<", start_line, start_column)
          end
        when '>'
          advance
          if current_char == '='
            advance
            Token.new(:GTE, ">=", start_line, start_column)
          else
            Token.new(:GT, ">", start_line, start_column)
          end
        when '('
          advance
          Token.new(:LPAREN, "(", start_line, start_column)
        when ')'
          advance
          Token.new(:RPAREN, ")", start_line, start_column)
        when '{'
          advance
          Token.new(:LBRACE, "{", start_line, start_column)
        when '}'
          advance
          Token.new(:RBRACE, "}", start_line, start_column)
        when '['
          advance
          Token.new(:LBRACKET, "[", start_line, start_column)
        when ']'
          advance
          Token.new(:RBRACKET, "]", start_line, start_column)
        when ':'
          advance
          Token.new(:COLON, ":", start_line, start_column)
        when ','
          advance
          Token.new(:COMMA, ",", start_line, start_column)
        when '.'
          advance
          Token.new(:DOT, ".", start_line, start_column)
        when '|'
          advance
          Token.new(:PIPE, "|", start_line, start_column)
        else
          raise "Unexpected character: #{current_char}"
        end
      end
    end
  end
end
