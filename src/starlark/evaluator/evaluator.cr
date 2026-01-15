require "../parser/parser"
require "../types/value"

module Starlark
  class Evaluator
    @globals : Hash(String, Value)
    @builtins : Hash(String, Value)

    def initialize
      @globals = {} of String => Value
      @builtins = {} of String => Value
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
      when AST::Index
        evaluate_index(expr)
      when AST::Slice
        evaluate_slice(expr)
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
      # Create a function value
      # For now, just store the AST node
      # FIXME: Implement proper function closure
      @globals[stmt.name] = Value.new(stmt) # Temporarily store AST
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
      @globals[name]? || @builtins[name]? || raise "Undefined variable: #{name}"
    end
  end
end
