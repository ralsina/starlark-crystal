module Starlark
  module AST
    abstract class Node
    end

    abstract class Expr < Node
    end

    abstract class Stmt < Node
    end

    # Literals
    class LiteralNone < Expr
    end

    class LiteralBool < Expr
      # ameba:disable Naming/QueryBoolMethods
      getter value : Bool

      def initialize(@value)
      end
    end

    class LiteralInt < Expr
      getter value : Int64

      def initialize(@value)
      end
    end

    class LiteralString < Expr
      getter value : String

      def initialize(@value)
      end
    end

    # Identifier
    class Identifier < Expr
      getter name : String

      def initialize(@name)
      end
    end

    # Binary operations
    class BinaryOp < Expr
      getter left : Expr
      getter op : Symbol
      getter right : Expr

      def initialize(@left, @op, @right)
      end
    end

    # Unary operations
    class UnaryOp < Expr
      getter op : Symbol
      getter operand : Expr

      def initialize(@op, @operand)
      end
    end

    # List literal
    class List < Expr
      getter elements : Array(Expr)

      def initialize(@elements)
      end
    end

    # Dict literal
    class Dict < Expr
      getter entries : Array({Expr, Expr})

      def initialize(@entries)
      end
    end

    # Index expression
    class Index < Expr
      getter object : Expr
      getter index : Expr

      def initialize(@object, @index)
      end
    end

    # Slice expression
    class Slice < Expr
      getter object : Expr
      getter start : Expr?
      getter end_index : Expr?

      def initialize(@object, @start = nil, @end_index = nil)
      end
    end

    # Function call
    class Call < Expr
      getter func : Expr
      getter args : Array(Expr)

      def initialize(@func, @args = [] of Expr)
      end
    end

    # Tuple literal
    class TupleLiteral < Expr
      getter elements : Array(Expr)

      def initialize(@elements)
      end
    end

    # Statements
    class Assign < Stmt
      getter target : Expr
      getter value : Expr

      def initialize(@target, @value)
      end
    end

    class If < Stmt
      getter condition : Expr
      getter then_block : Array(Stmt)
      getter elif_blocks : Array(Tuple(Expr, Array(Stmt)))
      getter else_block : Array(Stmt)?

      def initialize(@condition, @then_block, @elif_blocks = [] of Tuple(Expr, Array(Stmt)), @else_block = nil)
      end
    end

    class For < Stmt
      getter var : Identifier
      getter iterable : Expr
      getter body : Array(Stmt)

      def initialize(@var, @iterable, @body)
      end
    end

    class Return < Stmt
      getter value : Expr?

      def initialize(@value = nil)
      end
    end

    class Def < Stmt
      getter name : String
      getter params : Array(String)
      getter body : Array(Stmt)

      def initialize(@name, @params, @body)
      end
    end

    class ExprStmt < Stmt
      getter expr : Expr

      def initialize(@expr)
      end
    end

    class Pass < Stmt
    end
  end
end
