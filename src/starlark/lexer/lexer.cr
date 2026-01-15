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
            raise "Unexpected character: #{char}"
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
        type = KEYWORDS[value]?
        type ||= :IDENTIFIER

        Token.new(type, value, start_line, start_column)
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
    end
  end
end
