module Starlark
  module Lexer
    struct Token
      getter type : Symbol
      getter value : String?
      getter line : Int32
      getter column : Int32

      def initialize(@type : Symbol, @value : String?, @line : Int32, @column : Int32)
      end

      def self.eof(line : Int32, column : Int32) : Token
        new(:EOF, nil, line, column)
      end

      def eof? : Bool
        @type == :EOF
      end
    end
  end
end
