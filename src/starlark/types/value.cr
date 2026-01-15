require "../parser/ast"

module Starlark
  # Closure represents a user-defined function with its captured environment
  class Closure
    getter params : Array(String)
    getter body : Array(AST::Stmt)
    getter env : Hash(String, Value)

    def initialize(@params, @body, @env)
    end
  end

  class Value
    getter type : String
    getter? frozen : Bool

    # Union of all possible value types
    # For tuples, we use Array but mark them with type "tuple"
    @value : (Nil | Bool | Int64 | String | Array(Value) | Hash(Value, Value) | Closure | AST::Node)

    def initialize(@value, explicit_type : String? = nil, @frozen : Bool = false)
      @type = if explicit_type
                explicit_type
              else
                case @value
                when Nil       then "NoneType"
                when Bool      then "bool"
                when Int64     then "int"
                when String    then "string"
                when Array     then "list"
                when Hash      then "dict"
                when Closure   then "function"
                when AST::Node then "function" # Temporary for function definitions
                else
                  raise "Unknown type: #{@value.class}"
                end
              end
    end

    def freeze : Value
      return self if @frozen

      case v = @value
      when Array
        # Recursively freeze all elements
        frozen_elements = v.map(&.freeze)
        @value = frozen_elements
      when Hash
        # Recursively freeze all keys and values
        frozen_dict = {} of Value => Value
        v.each do |key, val|
          frozen_key = key.freeze
          frozen_val = val.freeze
          frozen_dict[frozen_key] = frozen_val
        end
        @value = frozen_dict
      when Closure
        # Freeze the closure's environment
        v.env.transform_values(&.freeze)
      end

      @frozen = true
      self
    end

    def self.builtin_placeholder : Value
      new("builtin", "builtin")
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

    def as_closure : Closure
      @value.as(Closure)
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
