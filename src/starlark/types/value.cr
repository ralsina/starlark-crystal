require "../parser/ast"

module Starlark
  class Value
    getter type : String

    # Union of all possible value types
    @value : (Nil | Bool | Int64 | String | Array(Value) | Hash(Value, Value) | AST::Node)

    def initialize(@value)
      @type = case @value
              when Nil       then "NoneType"
              when Bool      then "bool"
              when Int64     then "int"
              when String    then "string"
              when Array     then "list"
              when Hash      then "dict"
              when AST::Node then "function" # Temporary for function definitions
              else
                raise "Unknown type: #{@value.class}"
              end
    end

    def self.none : Value
      new(nil)
    end

    def truth : Bool
      case v = @value
      when Nil
        false
      when Bool
        v
      when Int64
        v != 0
      when String
        !v.empty?
      when Array
        !v.empty?
      when Hash
        !v.empty?
      else
        false
      end
    end

    def as_none : Nil
      @value.as(Nil)
    end

    def as_bool : Bool
      @value.as(Bool)
    end

    def as_int : Int64
      @value.as(Int64)
    end

    def as_string : String
      @value.as(String)
    end

    def as_list : Array(Value)
      @value.as(Array(Value))
    end

    def as_dict : Hash(Value, Value)
      @value.as(Hash(Value, Value))
    end

    def as_ast : AST::Node
      @value.as(AST::Node)
    end

    def to_s(io : IO)
      io << @value.inspect
    end

    # For hash keys
    def hash(hasher)
      @value.hash(hasher)
    end

    def ==(other : Value) : Bool
      @value == other.@value
    end
  end
end
