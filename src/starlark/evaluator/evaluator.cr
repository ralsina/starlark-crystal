require "../parser/parser"
require "../types/value"

module Starlark
  # Type alias for builtin functions
  alias BuiltinFunction = Array(Value) -> Value

  class Evaluator
    @globals : Hash(String, Value)
    @builtins : Hash(String, BuiltinFunction)

    def initialize
      @globals = {} of String => Value
      @builtins = {} of String => BuiltinFunction
      register_default_builtins
    end

    def set_global(name : String, value : Value)
      @globals[name] = value
    end

    def register_builtin(name : String, func : BuiltinFunction)
      @builtins[name] = func
    end

    def eval_file(path : String) : Value?
      source = File.read(path)
      eval_multi(source)
    end

    def eval_multi(source : String) : Value?
      lines = source.split('\n')
      result = nil
      lines.each do |line|
        line = line.strip
        if !line.empty?
          result = eval_stmt(line)
        end
      end
      result
    end

    def eval(source : String) : Value
      parser = Parser.new(source)
      expr = parser.parse_expression
      evaluate_expr(expr)
    end

    def eval_stmt(source : String) : Value?
      parser = Parser.new(source)
      stmt = parser.parse_statement
      evaluate_stmt(stmt)
    end

    def get_global(name : String) : Value
      @globals[name]? || raise "Undefined variable: #{name}"
    end

    private def evaluate_expr(expr : AST::Expr) : Value
      case expr
      when AST::LiteralNone
        Value.none
      when AST::LiteralBool
        Value.new(expr.value)
      when AST::LiteralInt
        Value.new(expr.value)
      when AST::LiteralString
        Value.new(expr.value)
      when AST::Identifier
        lookup_variable(expr.name)
      when AST::BinaryOp
        evaluate_binary_op(expr)
      when AST::UnaryOp
        evaluate_unary_op(expr)
      when AST::List
        evaluate_list(expr)
      when AST::Dict
        evaluate_dict(expr)
      when AST::TupleLiteral
        evaluate_tuple(expr)
      when AST::Index
        evaluate_index(expr)
      when AST::Slice
        evaluate_slice(expr)
      when AST::Call
        evaluate_call(expr)
      else
        raise "Unknown expression type: #{expr.class}"
      end
    end

    private def evaluate_stmt(stmt : AST::Stmt) : Value?
      case stmt
      when AST::Assign
        value = evaluate_expr(stmt.value)
        @globals[stmt.target.as(AST::Identifier).name] = value
        nil
      when AST::ExprStmt
        evaluate_expr(stmt.expr)
      when AST::If
        evaluate_if(stmt)
      when AST::For
        evaluate_for(stmt)
      when AST::Return
        evaluate_return(stmt)
      when AST::Def
        evaluate_def(stmt)
      when AST::Pass
        nil
      else
        raise "Unknown statement type: #{stmt.class}"
      end
    end

    private def evaluate_if(stmt : AST::If) : Value?
      if evaluate_expr(stmt.condition).truth
        stmt.then_block.each { |statement| evaluate_stmt(statement) }
      else
        stmt.elif_blocks.each do |cond, body|
          if evaluate_expr(cond).truth
            body.each { |statement| evaluate_stmt(statement) }
            return nil
          end
        end

        if else_block = stmt.else_block
          else_block.each { |statement| evaluate_stmt(statement) }
        end
      end
      nil
    end

    private def evaluate_for(stmt : AST::For) : Value?
      iterable = evaluate_expr(stmt.iterable)
      var_name = stmt.var.name

      case iterable.type
      when "list"
        iterable.as_list.each do |item|
          @globals[var_name] = item
          stmt.body.each { |statement| evaluate_stmt(statement) }
        end
      else
        raise "Cannot iterate over #{iterable.type}"
      end

      nil
    end

    private def evaluate_return(stmt : AST::Return) : Value?
      if value = stmt.value
        evaluate_expr(value)
      else
        Value.none
      end
    end

    private def evaluate_def(stmt : AST::Def) : Value?
      # Create a closure with the current environment
      closure = Closure.new(stmt.params, stmt.body, @globals.dup)
      @globals[stmt.name] = Value.new(closure)
      nil
    end

    private def evaluate_binary_op(expr : AST::BinaryOp) : Value
      left_val = evaluate_expr(expr.left)
      right_val = evaluate_expr(expr.right)

      case expr.op
      when :PLUS then evaluate_plus(left_val, right_val)
      when :STAR then evaluate_star(left_val, right_val)
      when :MINUS, :SLASH, :PERCENT, :SLASHSLASH
        evaluate_arithmetic(left_val, right_val, expr.op)
      when :EQEQ   then evaluate_equality(left_val, right_val)
      when :BANGEQ then evaluate_inequality(left_val, right_val)
      when :LT, :LTE, :GT, :GTE
        evaluate_comparison(left_val, right_val, expr.op)
      when :AND, :OR
        evaluate_logical(left_val, right_val, expr.op)
      else
        raise "Unknown operator: #{expr.op}"
      end
    end

    private def evaluate_unary_op(expr : AST::UnaryOp) : Value
      operand_val = evaluate_expr(expr.operand)

      case expr.op
      when :MINUS
        case operand_val.type
        when "int"
          Value.new(-operand_val.as_int)
        else
          raise "Cannot apply unary minus to #{operand_val.type}"
        end
      when :PLUS
        operand_val
      else
        raise "Unknown unary operator: #{expr.op}"
      end
    end

    private def evaluate_plus(left : Value, right : Value) : Value
      case {left.type, right.type}
      when {"int", "int"}
        Value.new(left.as_int + right.as_int)
      when {"string", "string"}
        Value.new(left.as_string + right.as_string)
      else
        raise "Cannot add #{left.type} and #{right.type}"
      end
    end

    private def evaluate_star(left : Value, right : Value) : Value
      case {left.type, right.type}
      when {"int", "int"}
        Value.new(left.as_int * right.as_int)
      when {"string", "int"}
        Value.new(left.as_string * right.as_int.to_i)
      else
        raise "Cannot multiply #{left.type} and #{right.type}"
      end
    end

    private def evaluate_arithmetic(left : Value, right : Value, op : Symbol) : Value
      left_int = left.as_int
      right_int = right.as_int

      result = case op
               when :MINUS      then left_int - right_int
               when :SLASH      then left_int // right_int
               when :PERCENT    then left_int % right_int
               when :SLASHSLASH then left_int // right_int
               else
                 raise "Unknown arithmetic operator: #{op}"
               end

      Value.new(result)
    end

    private def evaluate_comparison(left : Value, right : Value, op : Symbol) : Value
      left_int = left.as_int
      right_int = right.as_int

      result = case op
               when :LT  then left_int < right_int
               when :LTE then left_int <= right_int
               when :GT  then left_int > right_int
               when :GTE then left_int >= right_int
               else
                 raise "Unknown comparison operator: #{op}"
               end

      Value.new(result)
    end

    private def evaluate_equality(left : Value, right : Value) : Value
      Value.new(left == right)
    end

    private def evaluate_inequality(left : Value, right : Value) : Value
      Value.new(!(left == right))
    end

    private def evaluate_logical(left : Value, right : Value, op : Symbol) : Value
      case op
      when :AND
        Value.new(left.truth && right.truth)
      when :OR
        Value.new(left.truth || right.truth)
      else
        raise "Unknown logical operator: #{op}"
      end
    end

    private def evaluate_list(expr : AST::List) : Value
      elements = expr.elements.map { |e| evaluate_expr(e) }
      Value.new(elements)
    end

    private def evaluate_tuple(expr : AST::TupleLiteral) : Value
      elements = expr.elements.map { |e| evaluate_expr(e) }
      Value.new(elements, "tuple")
    end

    private def evaluate_call(expr : AST::Call) : Value
      # First check if this is a direct identifier call
      func_name = case func = expr.func
                  when AST::Identifier
                    func.name
                  else
                    nil
                  end

      args = expr.args.map { |arg| evaluate_expr(arg) }

      # Check if it's a built-in function
      if func_name && @builtins.has_key?(func_name)
        return call_builtin(func_name, args)
      end

      # Try to evaluate as expression
      func_value = evaluate_expr(expr.func)

      unless func_value.type == "function"
        raise "Cannot call non-function: #{func_value.type}"
      end

      # Check if it's a closure
      if func_value.@value.is_a?(Closure)
        closure = func_value.as_closure
        return call_closure(closure, args)
      end

      # Fallback to old AST-based approach (shouldn't happen anymore)
      ast_node = func_value.as_ast
      if ast_node.is_a?(AST::Def)
        raise "Old-style function definitions not supported"
      end

      raise "Cannot call this function"
    end

    private def call_closure(closure : Closure, args : Array(Value)) : Value
      # Check argument count
      if args.size != closure.params.size
        raise "Function expects #{closure.params.size} arguments, got #{args.size}"
      end

      # Create new environment by cloning the closure's environment
      old_globals = @globals
      @globals = closure.env.dup

      # Bind parameters to arguments
      closure.params.each_with_index do |param_name, index|
        @globals[param_name] = args[index]
      end

      # Execute function body
      result = nil
      return_value = nil
      closure.body.each do |statement|
        result = evaluate_stmt(statement)
        # Check if this is a return statement
        if stmt = statement
          if stmt.is_a?(AST::Return)
            return_value = result
            break
          end
        end
      end

      # Restore globals
      @globals = old_globals

      # Return the result (or None if no explicit return)
      return_value || Value.none
    end

    private def call_builtin(name : String, args : Array(Value)) : Value
      builtin_func = @builtins[name]?
      if builtin_func
        builtin_func.call(args)
      else
        raise "Unknown built-in function: #{name}"
      end
    end

    private def register_default_builtins
      @builtins["len"] = ->builtin_len(Array(Value))
      @builtins["range"] = ->builtin_range(Array(Value))
      @builtins["str"] = ->builtin_str(Array(Value))
      @builtins["int"] = ->builtin_int(Array(Value))
      @builtins["bool"] = ->builtin_bool(Array(Value))
      @builtins["list"] = ->builtin_list(Array(Value))
      @builtins["dict"] = ->builtin_dict(Array(Value))
      @builtins["tuple"] = ->builtin_tuple(Array(Value))
    end

    private def builtin_len(args : Array(Value)) : Value
      if args.size != 1
        raise "len() takes exactly 1 argument (#{args.size} given)"
      end

      arg = args[0]
      length = case arg.type
               when "string"
                 arg.as_string.size.to_i64
               when "list", "tuple"
                 arg.as_list.size.to_i64
               when "dict"
                 arg.as_dict.size.to_i64
               else
                 raise "len() unsupported type: #{arg.type}"
               end

      Value.new(length)
    end

    private def builtin_range(args : Array(Value)) : Value
      if args.size < 1 || args.size > 3
        raise "range() takes 1-3 arguments (#{args.size} given)"
      end

      # Convert all args to integers
      int_args = args.map { |arg|
        case arg.type
        when "int"
          arg.as_int
        else
          raise "range() arguments must be integers"
        end
      }

      start_value = 0_i64
      stop_value = 0_i64
      step_value = 1_i64

      case int_args.size
      when 1
        stop_value = int_args[0]
      when 2
        start_value = int_args[0]
        stop_value = int_args[1]
      when 3
        start_value = int_args[0]
        stop_value = int_args[1]
        step_value = int_args[2]
        if step_value == 0
          raise "range() step cannot be zero"
        end
      end

      # Generate the range
      result = [] of Value
      current = start_value

      if step_value > 0
        while current < stop_value
          result << Value.new(current)
          current += step_value
        end
      else
        while current > stop_value
          result << Value.new(current)
          current += step_value
        end
      end

      Value.new(result)
    end

    private def builtin_str(args : Array(Value)) : Value
      if args.size != 1
        raise "str() takes exactly 1 argument (#{args.size} given)"
      end

      arg = args[0]
      string_value = case arg.type
                     when "int"
                       arg.as_int.to_s
                     when "string"
                       arg.as_string
                     when "bool"
                       arg.as_bool ? "True" : "False"
                     when "NoneType"
                       "None"
                     else
                       arg.to_s
                     end

      Value.new(string_value)
    end

    private def builtin_int(args : Array(Value)) : Value
      if args.size != 1
        raise "int() takes exactly 1 argument (#{args.size} given)"
      end

      arg = args[0]
      int_value = case arg.type
                  when "int"
                    arg.as_int
                  when "string"
                    arg.as_string.to_i64
                  when "bool"
                    arg.as_bool ? 1_i64 : 0_i64
                  else
                    raise "int() unsupported type: #{arg.type}"
                  end

      Value.new(int_value)
    end

    private def builtin_bool(args : Array(Value)) : Value
      if args.size != 1
        raise "bool() takes exactly 1 argument (#{args.size} given)"
      end

      Value.new(args[0].truth)
    end

    private def builtin_list(args : Array(Value)) : Value
      if args.size != 1
        raise "list() takes exactly 1 argument (#{args.size} given)"
      end

      arg = args[0]
      list_value = case arg.type
                   when "list", "tuple"
                     arg.as_list.dup
                   when "string"
                     arg.as_string.chars.map { |c| Value.new(c.to_s) }
                   else
                     raise "list() unsupported type: #{arg.type}"
                   end

      Value.new(list_value)
    end

    private def builtin_dict(args : Array(Value)) : Value
      if args.size != 1
        raise "dict() takes exactly 1 argument (#{args.size} given)"
      end

      arg = args[0]
      dict_value = case arg.type
                   when "dict"
                     arg.as_dict
                   when "list", "tuple"
                     # Create dict from list of tuples
                     dict = {} of Value => Value
                     arg.as_list.each do |item|
                       # Each item should be a tuple with 2 elements
                       if item.type == "tuple"
                         tuple_elements = item.as_list
                         if tuple_elements.size == 2
                           dict[tuple_elements[0]] = tuple_elements[1]
                         end
                       end
                     end
                     dict
                   else
                     raise "dict() unsupported type: #{arg.type}"
                   end

      Value.new(dict_value)
    end

    private def builtin_tuple(args : Array(Value)) : Value
      if args.size != 1
        raise "tuple() takes exactly 1 argument (#{args.size} given)"
      end

      arg = args[0]
      tuple_value = case arg.type
                    when "tuple"
                      # Return as is (it's already a tuple internally)
                      arg.as_list
                    when "list"
                      arg.as_list
                    else
                      raise "tuple() unsupported type: #{arg.type}"
                    end

      Value.new(tuple_value, "tuple")
    end

    private def evaluate_dict(expr : AST::Dict) : Value
      dict = {} of Value => Value
      expr.entries.each do |key_expr, value_expr|
        key = evaluate_expr(key_expr)
        value = evaluate_expr(value_expr)
        dict[key] = value
      end
      Value.new(dict)
    end

    private def evaluate_index(expr : AST::Index) : Value
      object = evaluate_expr(expr.object)
      index = evaluate_expr(expr.index)

      case object.type
      when "list"
        list = object.as_list
        idx = index.as_int

        # Handle negative indexing
        if idx < 0
          idx = list.size + idx
        end

        if idx < 0 || idx >= list.size
          raise "Index out of bounds: #{index.as_int}"
        end

        list[idx]
      when "dict"
        dict = object.as_dict
        unless dict.has_key?(index)
          raise "Key not found: #{index}"
        end
        dict[index]
      when "string"
        str = object.as_string
        idx = index.as_int

        # Handle negative indexing
        if idx < 0
          idx = str.size + idx
        end

        if idx < 0 || idx >= str.size
          raise "Index out of bounds: #{index.as_int}"
        end

        Value.new(str[idx].to_s)
      else
        raise "Cannot index #{object.type}"
      end
    end

    private def evaluate_slice(expr : AST::Slice) : Value
      object = evaluate_expr(expr.object)

      # Only lists support slicing for now
      unless object.type == "list"
        raise "Cannot slice #{object.type}"
      end

      list = object.as_list
      list_size = list.size.to_i64

      # Parse start index
      start_idx = 0_i64
      if start_expr = expr.start
        start_val = evaluate_expr(start_expr)
        start_idx = start_val.as_int

        # Handle negative start
        if start_idx < 0
          start_idx = list_size + start_idx
          start_idx = 0_i64 if start_idx < 0
        end
      end

      # Parse end index
      end_idx = list_size
      if end_expr = expr.end_index
        end_val = evaluate_expr(end_expr)
        end_idx = end_val.as_int

        # Handle negative end
        if end_idx < 0
          end_idx = list_size + end_idx
        end
      end

      # Clamp indices
      start_idx = {0_i64, start_idx}.max
      end_idx = {list_size, end_idx}.min
      start_idx = {start_idx, end_idx}.min

      # Extract slice
      result = list[start_idx...end_idx]
      Value.new(result)
    end

    private def lookup_variable(name : String) : Value
      @globals[name]? || begin
        if @builtins.has_key?(name)
          # Return a placeholder value that indicates this is a builtin
          # The actual call will be handled by evaluate_call
          Value.builtin_placeholder
        else
          raise "Undefined variable: #{name}"
        end
      end
    end
  end
end
