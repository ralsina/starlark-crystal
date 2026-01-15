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
  end
end
