# Starlark Interpreter Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a pure Crystal Starlark interpreter for evaluating configuration files and embedded scripting.

**Architecture:** Three-stage pipeline (Lexer → Parser → Evaluator) with value type system, scope chains, built-in functions, and Crystal integration API. Starlark spec compliance with frozen semantics.

**Tech Stack:** Crystal 1.13.0, Ameba (linting), Crystal spec (testing)

---

## PHASE 1: LEXER

### Task 1: Define Token Type

**Files:**
- Create: `src/starlark/lexer/token.cr`

**Step 1: Write the failing spec**

```crystal
require "spec"

describe Starlark::Lexer::Token do
  it "creates a token with type and value" do
    token = Starlark::Lexer::Token.new(:IDENTIFIER, "foo", 1, 1)
    token.type.should eq(:IDENTIFIER)
    token.value.should eq("foo")
    token.line.should eq(1)
    token.column.should eq(1)
  end

  it "creates EOF token" do
    token = Starlark::Lexer::Token.eof(10, 20)
    token.type.should eq(:EOF)
    token.value.should be_nil
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/lexer/token_spec.cr`
Expected: FAIL with "Token not defined"

**Step 3: Write minimal implementation**

```crystal
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
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/lexer/token_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/lexer/token.cr spec/starlark/lexer/token_spec.cr
git commit -m "feat: add Token type for lexer"
```

---

### Task 2: Lexer - Basic Keywords and Identifiers

**Files:**
- Create: `src/starlark/lexer/lexer.cr`
- Test: `spec/starlark/lexer/lexer_spec.cr`

**Step 1: Write failing spec for keyword tokenization**

```crystal
require "spec"

describe Starlark::Lexer do
  it "tokenizes keywords" do
    lexer = Starlark::Lexer.new("def return if else elif for in load")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([
      :DEF, :RETURN, :IF, :ELSE, :ELIF, :FOR, :IN, :LOAD, :EOF
    ])
  end

  it "tokenizes identifiers" do
    lexer = Starlark::Lexer.new("foo bar_baz _private")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([:IDENTIFIER, :IDENTIFIER, :IDENTIFIER, :EOF])
    tokens[0].value.should eq("foo")
    tokens[1].value.should eq("bar_baz")
    tokens[2].value.should eq("_private")
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/lexer/lexer_spec.cr`
Expected: FAIL with "Lexer not defined"

**Step 3: Write minimal implementation**

```crystal
require "./token"

module Starlark
  module Lexer
    KEYWORDS = {
      "and"    => :AND, "as" => :AS, "assert" => :ASSERT,
      "break"  => :BREAK, "class" => :CLASS, "continue" => :CONTINUE,
      "def"    => :DEF, "del" => :DEL, "elif" => :ELIF,
      "else"   => :ELSE, "for" => :FOR, "if" => :IF,
      "in"     => :IN, "lambda" => :LAMBDA, "load" => :LOAD,
      "not"    => :NOT, "or" => :OR, "pass" => :PASS,
      "return" => :RETURN, "while" => :WHILE
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

        value = ""
        while @pos < @source.size && (current_char.ascii_alphanumeric? || current_char == '_')
          value << current_char
          advance
        end

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
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/lexer/lexer_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/lexer/lexer.cr spec/starlark/lexer/lexer_spec.cr
git commit -m "feat: add keyword and identifier tokenization"
```

---

### Task 3: Lexer - Literals (Strings, Numbers, Booleans, None)

**Files:**
- Modify: `src/starlark/lexer/lexer.cr`
- Modify: `spec/starlark/lexer/lexer_spec.cr`

**Step 1: Write failing spec for literals**

```crystal
# Add to existing spec file

  it "tokenizes integers" do
    lexer = Starlark::Lexer.new("42 0 -123")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([:INTEGER, :INTEGER, :MINUS, :INTEGER, :EOF])
    tokens[0].value.should eq("42")
    tokens[1].value.should eq("0")
    tokens[3].value.should eq("123")
  end

  it "tokenizes strings" do
    lexer = Starlark::Lexer.new(%("hello" 'world' "escaped\\"quote"))
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([:STRING, :STRING, :STRING, :EOF])
    tokens[0].value.should eq("hello")
    tokens[1].value.should eq("world")
    tokens[2].value.should eq(%(escaped"quote))
  end

  it "tokenizes booleans and None" do
    lexer = Starlark::Lexer.new("True False None")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([:TRUE, :FALSE, :NONE, :EOF])
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/lexer/lexer_spec.cr`
Expected: FAIL (literals not implemented)

**Step 3: Implement literal tokenization**

Add to `Lexer#tokenize` after identifier check:

```crystal
elsif char.ascii_number?
  tokens << read_number
elsif char == '"' || char == '\''
  tokens << read_string
```

Add private methods:

```crystal
private def read_number : Token
  start_line = @line
  start_column = @column

  value = ""
  while @pos < @source.size && current_char.ascii_number?
    value << current_char
    advance
  end

  Token.new(:INTEGER, value, start_line, start_column)
end

private def read_string : Token
  start_line = @line
  start_column = @column
  quote = current_char
  advance  # consume opening quote

  value = ""
  while @pos < @source.size && current_char != quote
    if current_char == '\\'
      advance  # consume backslash
      if @pos < @source.size
        value << current_char
        advance
      end
    else
      value << current_char
      advance
    end
  end

  advance  # consume closing quote
  Token.new(:STRING, value, start_line, start_column)
end
```

Add `true`, `false`, `none` to KEYWORDS:
```crystal
"True"   => :TRUE, "False" => :FALSE, "None" => :NONE
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/lexer/lexer_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/lexer/lexer.cr spec/starlark/lexer/lexer_spec.cr
git commit -m "feat: add literal tokenization (numbers, strings, booleans, None)"
```

---

### Task 4: Lexer - Operators and Punctuation

**Files:**
- Modify: `src/starlark/lexer/lexer.cr`
- Modify: `spec/starlark/lexer/lexer_spec.cr`

**Step 1: Write failing spec**

```crystal
# Add to spec

  it "tokenizes operators" do
    lexer = Starlark::Lexer.new("+ - * / % // ** == != < <= > >= = += -= *= //=")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([
      :PLUS, :MINUS, :STAR, :SLASH, :PERCENT, :SLASHSLASH,
      :STARSTAR, :EQEQ, :BANGEQ, :LT, :LTE, :GT, :GTE,
      :ASSIGN, :PLUSEQ, :MINUSEQ, :STAREQ, :SLASHSLASHEQ,
      :EOF
    ])
  end

  it "tokenizes punctuation" do
    lexer = Starlark::Lexer.new("(){}[]:,.|")
    tokens = lexer.tokenize

    tokens.map(&.type).should eq([
      :LPAREN, :RPAREN, :LBRACE, :RBRACE, :LBRACKET, :RBRACKET,
      :COLON, :COMMA, :DOT, :PIPE, :EOF
    ])
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/lexer/lexer_spec.cr`
Expected: FAIL

**Step 3: Implement operators**

Add to `Lexer#tokenize` in main loop:

```crystal
else
  tokens << read_operator_or_punctuation
end
```

Add method:

```crystal
private def read_operator_or_punctuation : Token
  start_line = @line
  start_column = @column

  case current_char
  when '+'
    advance
    if peek_char == '='
      advance
      Token.new(:PLUSEQ, "+=", start_line, start_column)
    else
      Token.new(:PLUS, "+", start_line, start_column)
    end
  when '-'
    advance
    Token.new(:MINUS, "-", start_line, start_column)
  when '*'
    advance
    if peek_char == '*'
      advance
      Token.new(:STARSTAR, "**", start_line, start_column)
    elsif peek_char == '='
      advance
      Token.new(:STAREQ, "*=", start_line, start_column)
    else
      Token.new(:STAR, "*", start_line, start_column)
    end
  when '/'
    advance
    if peek_char == '/'
      advance
      if peek_char == '='
        advance
        Token.new(:SLASHSLASHEQ, "//=", start_line, start_column)
      else
        Token.new(:SLASHSLASH, "//", start_line, start_column)
      end
    elsif peek_char == '='
      advance
      Token.new(:SLASHEQ, "/=", start_line, start_column)
    else
      Token.new(:SLASH, "/", start_line, start_column)
    end
  when '%'
    advance
    Token.new(:PERCENT, "%", start_line, start_column)
  when '='
    advance
    if peek_char == '='
      advance
      Token.new(:EQEQ, "==", start_line, start_column)
    else
      Token.new(:ASSIGN, "=", start_line, start_column)
    end
  when '!'
    advance
    if peek_char == '='
      advance
      Token.new(:BANGEQ, "!=", start_line, start_column)
    else
      raise "Unexpected character: !"
    end
  when '<'
    advance
    if peek_char == '='
      advance
      Token.new(:LTE, "<=", start_line, start_column)
    else
      Token.new(:LT, "<", start_line, start_column)
    end
  when '>'
    advance
    if peek_char == '='
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

private def peek_char : Char?
  @source[@pos + 1]?
end
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/lexer/lexer_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/lexer/lexer.cr spec/starlark/lexer/lexer_spec.cr
git commit -m "feat: add operator and punctuation tokenization"
```

---

## PHASE 2: PARSER

### Task 5: AST Node Base Classes

**Files:**
- Create: `src/starlark/parser/ast.cr`
- Test: `spec/starlark/parser/ast_spec.cr`

**Step 1: Write failing spec**

```crystal
require "spec"

describe Starlark::AST::Node do
  it "creates a literal node" do
    node = Starlark::AST::LiteralInt.new(42)
    node.value.should eq(42)
  end

  it "creates an identifier node" do
    node = Starlark::AST::Identifier.new("foo")
    node.name.should eq("foo")
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/parser/ast_spec.cr`
Expected: FAIL

**Step 3: Implement AST base classes**

```crystal
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
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/parser/ast_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/parser/ast.cr spec/starlark/parser/ast_spec.cr
git commit -m "feat: add AST base classes and literal/identifier nodes"
```

---

### Task 6: Parser - Expression Parsing (Literals, Identifiers, Binary Ops)

**Files:**
- Create: `src/starlark/parser/parser.cr`
- Test: `spec/starlark/parser/parser_spec.cr`

**Step 1: Write failing spec**

```crystal
require "spec"

describe Starlark::Parser do
  it "parses integer literals" do
    parser = Starlark::Parser.new("42")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::LiteralInt)
    expr.as(Starlark::AST::LiteralInt).value.should eq(42)
  end

  it "parses string literals" do
    parser = Starlark::Parser.new(%("hello"))
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::LiteralString)
    expr.as(Starlark::AST::LiteralString).value.should eq("hello")
  end

  it "parses boolean literals" do
    parser_true = Starlark::Parser.new("True")
    expr_true = parser_true.parse_expression
    expr_true.should be_a(Starlark::AST::LiteralBool)
    expr_true.as(Starlark::AST::LiteralBool).value.should eq(true)

    parser_false = Starlark::Parser.new("False")
    expr_false = parser_false.parse_expression
    expr_false.as(Starlark::AST::LiteralBool).value.should eq(false)
  end

  it "parses None" do
    parser = Starlark::Parser.new("None")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::LiteralNone)
  end

  it "parses identifiers" do
    parser = Starlark::Parser.new("foo")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::Identifier)
    expr.as(Starlark::AST::Identifier).name.should eq("foo")
  end

  it "parses binary operators" do
    parser = Starlark::Parser.new("1 + 2")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::BinaryOp)
    binary = expr.as(Starlark::AST::BinaryOp)
    binary.op.should eq(:PLUS)
    binary.left.should be_a(Starlark::AST::LiteralInt)
    binary.right.should be_a(Starlark::AST::LiteralInt)
  end

  it "respects operator precedence" do
    parser = Starlark::Parser.new("1 + 2 * 3")
    expr = parser.parse_expression

    expr.should be_a(Starlark::AST::BinaryOp)
    binary = expr.as(Starlark::AST::BinaryOp)
    binary.op.should eq(:PLUS)  # + is lower precedence than *
    binary.left.should be_a(Starlark::AST::LiteralInt)
    binary.right.should be_a(Starlark::AST::BinaryOp)
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/parser/parser_spec.cr`
Expected: FAIL

**Step 3: Implement parser**

```crystal
require "../lexer/lexer"
require "./ast"

module Starlark
  class Parser
    @tokens : Array(Lexer::Token)
    @pos : Int32

    def initialize(source : String)
      @tokens = Lexer.new(source).tokenize
      @pos = 0
    end

    def parse_expression : AST::Expr
      parse_binary_op(0)
    end

    # Precedence levels (higher = tighter binding)
    PRECEDENCE = {
      :OR       => 1,
      :AND      => 2,
      :EQEQ     => 3, :BANGEQ => 3, :LT => 3, :LTE => 3, :GT => 3, :GTE => 3,
      :PLUS     => 4, :MINUS => 4,
      :STAR     => 5, :SLASH => 5, :PERCENT => 5, :SLASHSLASH => 5,
      :STARSTAR => 6,
    }

    private def parse_binary_op(min_precedence : Int32) : AST::Expr
      left = parse_unary

      while @pos < @tokens.size
        op_token = current_token
        precedence = PRECEDENCE[op_token.type]?

        break if precedence.nil? || precedence < min_precedence

        advance
        right = parse_binary_op(precedence + 1)
        left = AST::BinaryOp.new(left, op_token.type, right)
      end

      left
    end

    private def parse_unary : AST::Expr
      # For now, just handle primary expressions
      parse_primary
    end

    private def parse_primary : AST::Expr
      token = current_token

      case token.type
      when :INTEGER
        advance
        AST::LiteralInt.new(token.value.to_i64)
      when :STRING
        advance
        AST::LiteralString.new(token.value)
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
        AST::Identifier.new(token.value)
      when :LPAREN
        advance
        expr = parse_expression
        expect(:RPAREN)
        expr
      else
        raise "Unexpected token in expression: #{token.type}"
      end
    end

    private def expect(type : Symbol)
      if current_token.type == type
        advance
      else
        raise "Expected #{type}, got #{current_token.type}"
      end
    end

    private def current_token : Lexer::Token
      @tokens[@pos]?
    end

    private def advance
      @pos += 1
    end
  end
end
```

Add BinaryOp to AST:

```crystal
# In src/starlark/parser/ast.cr, add after Identifier:

    class BinaryOp < Expr
      getter left : Expr
      getter op : Symbol
      getter right : Expr

      def initialize(@left, @op, @right)
      end
    end
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/parser/parser_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/parser/parser.cr src/starlark/parser/ast.cr spec/starlark/parser/parser_spec.cr
git commit -m "feat: add expression parsing (literals, identifiers, binary ops)"
```

---

### Task 7: Parser - Statement Parsing (Assignment, If, For, Return)

**Files:**
- Modify: `src/starlark/parser/ast.cr`
- Modify: `src/starlark/parser/parser.cr`
- Modify: `spec/starlark/parser/parser_spec.cr`

**Step 1: Write failing spec for statements**

```crystal
# Add to parser_spec.cr

  it "parses assignment statements" do
    parser = Starlark::Parser.new("x = 42")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::Assign)
    assign = stmt.as(Starlark::AST::Assign)
    assign.target.should be_a(Starlark::AST::Identifier)
    assign.target.as(Starlark::AST::Identifier).name.should eq("x")
    assign.value.should be_a(Starlark::AST::LiteralInt)
  end

  it "parses if statements" do
    parser = Starlark::Parser.new("if True: pass")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::If)
  end

  it "parses for statements" do
    parser = Starlark::Parser.new("for x in [1, 2, 3]: pass")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::For)
  end

  it "parses return statements" do
    parser = Starlark::Parser.new("return 42")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::Return)
  end

  it "parses def statements" do
    parser = Starlark::Parser.new("def foo(): return 1")
    stmt = parser.parse_statement

    stmt.should be_a(Starlark::AST::Def)
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/parser/parser_spec.cr`
Expected: FAIL

**Step 3: Implement statement AST nodes and parsing**

Add to ast.cr:

```crystal
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
```

Add to parser.cr:

```crystal
    def parse_statement : AST::Stmt
      token = current_token

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

    private def parse_assignment_or_expr_stmt : AST::Stmt
      # Look ahead to see if this is an assignment
      save_pos = @pos
      identifier = parse_expression.as(AST::Identifier)

      if current_token.type == :ASSIGN || augmented_assign_op?
        # Assignment
        op = current_token.type
        advance
        value = parse_expression

        if op == :ASSIGN
          AST::Assign.new(identifier, value)
        else
          # Augmented assignment: x += 1 -> x = x + 1
          inner_op = augmented_to_binary(op)
          binary_expr = AST::BinaryOp.new(identifier, inner_op, value)
          AST::Assign.new(identifier, binary_expr)
        end
      else
        # Expression statement
        @pos = save_pos
        expr = parse_expression
        AST::ExprStmt.new(expr)
      end
    end

    private def augmented_assign_op? : Bool
      {:PLUSEQ, :MINUSEQ, :STAREQ, :SLASHEQ, :PERCENTEQ, :SLASHSLASHEQ}.includes?(current_token.type)
    end

    private def augmented_to_binary(augmented_op : Symbol) : Symbol
      case augmented_op
      when :PLUSEQ then :PLUS
      when :MINUSEQ then :MINUS
      when :STAREQ then :STAR
      when :SLASHEQ then :SLASH
      when :PERCENTEQ then :PERCENT
      when :SLASHSLASHEQ then :SLASHSLASH
      else raise "Unknown augmented operator: #{augmented_op}"
      end
    end

    private def parse_if : AST::If
      expect(:IF)
      condition = parse_expression
      expect(:COLON)
      then_block = parse_block

      elif_blocks = [] of Tuple(AST::Expr, Array(AST::Stmt))
      while current_token.type == :ELIF
        advance
        elif_cond = parse_expression
        expect(:COLON)
        elif_body = parse_block
        elif_blocks << {elif_cond, elif_body}
      end

      else_block = nil
      if current_token.type == :ELSE
        advance
        expect(:COLON)
        else_block = parse_block
      end

      AST::If.new(condition, then_block, elif_blocks, else_block)
    end

    private def parse_for : AST::For
      expect(:FOR)
      var_name = current_token.value
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
      unless current_token.type == :EOF || current_token.type == :NEWLINE
        value = parse_expression
      end
      AST::Return.new(value)
    end

    private def parse_def : AST::Def
      expect(:DEF)
      name = current_token.value
      expect(:IDENTIFIER)
      expect(:LPAREN)

      params = [] of String
      if current_token.type != :RPAREN
        params << current_token.value
        expect(:IDENTIFIER)
        while current_token.type == :COMMA
          advance
          params << current_token.value
          expect(:IDENTIFIER)
        end
      end

      expect(:RPAREN)
      expect(:COLON)
      body = parse_block

      AST::Def.new(name, params, body)
    end

    private def parse_block : Array(AST::Stmt)
      # Simple block parsing: one statement or multiple on separate lines
      # For now, just parse one indented statement
      # TODO: Implement proper indentation-based parsing
      stmts = [] of AST::Stmt
      stmts << parse_statement
      stmts
    end
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/parser/parser_spec.cr`
Expected: PASS (may need adjustments for indentation)

**Step 5: Commit**

```bash
git add src/starlark/parser/ast.cr src/starlark/parser/parser.cr spec/starlark/parser/parser_spec.cr
git commit -m "feat: add statement parsing (assignment, if, for, return, def)"
```

---

## PHASE 3: EVALUATOR

### Task 8: Value Type System

**Files:**
- Create: `src/starlark/types/value.cr`
- Test: `spec/starlark/types/value_spec.cr`

**Step 1: Write failing spec**

```crystal
require "spec"

describe Starlark::Value do
  it "creates None value" do
    val = Starlark::Value.none
    val.type.should eq("NoneType")
    val.truth.should eq(false)
  end

  it "creates boolean values" do
    val = Starlark::Value.new(true)
    val.type.should eq("bool")
    val.truth.should eq(true)

    val_false = Starlark::Value.new(false)
    val_false.truth.should eq(false)
  end

  it "creates integer values" do
    val = Starlark::Value.new(42_i64)
    val.type.should eq("int")
    val.truth.should eq(true)
  end

  it "creates string values" do
    val = Starlark::Value.new("hello")
    val.type.should eq("string")
    val.truth.should eq(true)

    empty = Starlark::Value.new("")
    empty.truth.should eq(false)
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/types/value_spec.cr`
Expected: FAIL

**Step 3: implement value types**

```crystal
module Starlark
  class Value
    getter type : String

    # Union of all possible value types
    @value : (Nil | Bool | Int64 | String | Array(Value) | Hash(Value, Value))

    def initialize(@value)
      @type = case @value
              when Nil then "NoneType"
              when Bool then "bool"
              when Int64 then "int"
              when String then "string"
              when Array then "list"
              when Hash then "dict"
              else
                raise "Unknown type: #{@value.class}"
              end
    end

    def self.none : Value
      new(nil)
    end

    def truth : Bool
      case @value
      when Nil then false
      when Bool then @value
      when Int64 then @value != 0
      when String then !@value.empty?
      when Array then !@value.empty?
      when Hash then !@value.empty?
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
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/types/value_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/types/value.cr spec/starlark/types/value_spec.cr
git commit -m "feat: add Value type system with basic types"
```

---

### Task 9: Evaluator - Expression Evaluation

**Files:**
- Create: `src/starlark/evaluator/evaluator.cr`
- Test: `spec/starlark/evaluator/evaluator_spec.cr`

**Step 1: Write failing spec**

```crystal
require "spec"

describe Starlark::Evaluator do
  it "evaluates integer literals" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval("42")
    result.should be_a(Starlark::Value)
    result.as_int.should eq(42)
  end

  it "evaluates string literals" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval(%("hello"))
    result.as_string.should eq("hello")
  end

  it "evaluates binary arithmetic" do
    evaluator = Starlark::Evaluator.new

    result = evaluator.eval("1 + 2")
    result.as_int.should eq(3)

    result = evaluator.eval("10 - 4")
    result.as_int.should eq(6)

    result = evaluator.eval("3 * 4")
    result.as_int.should eq(12)

    result = evaluator.eval("10 / 2")
    result.as_int.should eq(5)
  end

  it "evaluates comparison operators" do
    evaluator = Starlark::Evaluator.new

    result = evaluator.eval("1 < 2")
    result.as_bool.should eq(true)

    result = evaluator.eval("2 > 1")
    result.as_bool.should eq(true)

    result = evaluator.eval("1 == 1")
    result.as_bool.should eq(true)

    result = evaluator.eval("1 != 2")
    result.as_bool.should eq(true)
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/evaluator/evaluator_spec.cr`
Expected: FAIL

**Step 3: Implement expression evaluator**

```crystal
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
      else
        raise "Unknown expression type: #{expr.class}"
      end
    end

    private def evaluate_binary_op(expr : AST::BinaryOp) : Value
      left_val = evaluate_expr(expr.left)
      right_val = evaluate_expr(expr.right)

      case expr.op
      when :PLUS
        case {left_val.type, right_val.type}
        when {"int", "int"}
          Value.new(left_val.as_int + right_val.as_int)
        when {"string", "string"}
          Value.new(left_val.as_string + right_val.as_string)
        else
          raise "Cannot add #{left_val.type} and #{right_val.type}"
        end
      when :MINUS
        Value.new(left_val.as_int - right_val.as_int)
      when :STAR
        case {left_val.type, right_val.type}
        when {"int", "int"}
          Value.new(left_val.as_int * right_val.as_int)
        when {"string", "int"}
          Value.new(left_val.as_string * right_val.as_int.to_i)
        else
          raise "Cannot multiply #{left_val.type} and #{right_val.type}"
        end
      when :SLASH
        Value.new(left_val.as_int // right_val.as_int)
      when :PERCENT
        Value.new(left_val.as_int % right_val.as_int)
      when :SLASHSLASH
        Value.new(left_val.as_int // right_val.as_int)
      when :EQEQ
        Value.new(left_val == right_val)
      when :BANGEQ
        Value.new(!(left_val == right_val))
      when :LT
        Value.new(left_val.as_int < right_val.as_int)
      when :LTE
        Value.new(left_val.as_int <= right_val.as_int)
      when :GT
        Value.new(left_val.as_int > right_val.as_int)
      when :GTE
        Value.new(left_val.as_int >= right_val.as_int)
      when :AND
        Value.new(left_val.truth && right_val.truth)
      when :OR
        Value.new(left_val.truth || right_val.truth)
      else
        raise "Unknown operator: #{expr.op}"
      end
    end

    private def lookup_variable(name : String) : Value
      @globals[name]? || @builtins[name]?? raise "Undefined variable: #{name}"
    end
  end
end
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/evaluator/evaluator_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/evaluator/evaluator.cr spec/starlark/evaluator/evaluator_spec.cr
git commit -m "feat: add expression evaluation"
```

---

### Task 10: Evaluator - Statement Evaluation (Assignment, If, For)

**Files:**
- Modify: `src/starlark/evaluator/evaluator.cr`
- Modify: `spec/starlark/evaluator/evaluator_spec.cr`

**Step 1: Write failing spec for statements**

```crystal
# Add to evaluator_spec.cr

  it "evaluates assignment statements" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_stmt("x = 42")
    evaluator.get_global("x").as_int.should eq(42)
  end

  it "evaluates if statements" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_stmt("if True: x = 1")
    evaluator.get_global("x").as_int.should eq(1)
  end

  it "evaluates for loops over ranges" do
    evaluator = Starlark::Evaluator.new
    # This will need range support first
    # evaluator.eval_stmt("for i in range(3): x = i")
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/evaluator/evaluator_spec.cr`
Expected: FAIL

**Step 3: Implement statement evaluation**

Add to evaluator.cr:

```crystal
    def eval_stmt(source : String) : Value?
      parser = Parser.new(source)
      stmt = parser.parse_statement
      evaluate_stmt(stmt)
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
        stmt.then_block.each { |s| evaluate_stmt(s) }
      else
        stmt.elif_blocks.each do |cond, body|
          if evaluate_expr(cond).truth
            body.each { |s| evaluate_stmt(s) }
            return nil
          end
        end

        if else_block = stmt.else_block
          else_block.each { |s| evaluate_stmt(s) }
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
          stmt.body.each { |s| evaluate_stmt(s) }
        }
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
      # TODO: Implement proper function closure
      @globals[stmt.name] = Value.new(stmt)  # Temporarily store AST
      nil
    end

    def get_global(name : String) : Value
      @globals[name]? || raise "Undefined variable: #{name}"
    end
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/evaluator/evaluator_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/evaluator/evaluator.cr spec/starlark/evaluator/evaluator_spec.cr
git commit -m "feat: add statement evaluation (assignment, if, for)"
```

---

### Task 11: Evaluator - Lists and Dicts

**Files:**
- Modify: `src/starlark/parser/ast.cr`
- Modify: `src/starlark/evaluator/evaluator.cr`
- Modify: `spec/starlark/evaluator/evaluator_spec.cr`

**Step 1: Write failing spec for lists and dicts**

```crystal
# Add to evaluator_spec.cr

  it "evaluates list literals" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval("[1, 2, 3]")
    result.type.should eq("list")
    result.as_list.size.should eq(3)
    result.as_list[0].as_int.should eq(1)
  end

  it "evaluates dict literals" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval(%({"foo": "bar"}))
    result.type.should eq("dict")
  end

  it "evaluates list indexing" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval("[1, 2, 3][0]")
    result.as_int.should eq(1)
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/evaluator/evaluator_spec.cr`
Expected: FAIL

**Step 3: Implement list and dict parsing/evaluation**

Add to ast.cr:

```crystal
# Add after BinaryOp

    class ListExpr < Expr
      getter elements : Array(Expr)

      def initialize(@elements)
      end
    end

    class DictExpr < Expr
      getter entries : Array(Tuple(Expr, Expr))

      def initialize(@entries)
      end
    end

    class Index < Expr
      getter target : Expr
      getter index : Expr

      def initialize(@target, @index)
      end
    end
```

Add to parser.cr in `parse_primary`:

```crystal
      when :LBRACKET
        advance
        if current_token.type == :RBRACKET
          advance
          return AST::ListExpr.new([] of AST::Expr)
        end

        first = parse_expression
        if current_token.type == :FOR
          # List comprehension
          advance
          var_name = current_token.value
          expect(:IDENTIFIER)
          expect(:IN)
          iterable = parse_expression
          expect(:RBRACKET)
          return AST::ListComprehension.new(var_name, iterable, first)
        end

        elements = [first]
        while current_token.type == :COMMA
          advance
          break if current_token.type == :RBRACKET
          elements << parse_expression
        end
        expect(:RBRACKET)
        AST::ListExpr.new(elements)
      when :LBRACE
        advance
        if current_token.type == :RBRACE
          advance
          return AST::DictExpr.new([] of Tuple(AST::Expr, AST::Expr))
        end

        first_key = parse_expression
        expect(:COLON)
        first_value = parse_expression
        entries = [{first_key, first_value}]

        while current_token.type == :COMMA
          advance
          break if current_token.type == :RBRACE
          key = parse_expression
          expect(:COLON)
          value = parse_expression
          entries << {key, value}
        end
        expect(:RBRACE)
        AST::DictExpr.new(entries)
```

Add to evaluator.cr in `evaluate_expr`:

```crystal
      when AST::ListExpr
        elements = expr.elements.map { |e| evaluate_expr(e) }
        Value.new(elements)

      when AST::DictExpr
        dict = Hash(Value, Value).new
        expr.entries.each do |key_expr, value_expr|
          key = evaluate_expr(key_expr)
          value = evaluate_expr(value_expr)
          dict[key] = value
        end
        Value.new(dict)

      when AST::Index
        target = evaluate_expr(expr.target)
        index = evaluate_expr(expr.index)

        case target.type
        when "list"
          idx = index.as_int.to_i
          target.as_list[idx]
        when "dict"
          target.as_dict[index]
        else
          raise "Cannot index #{target.type}"
        end
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/evaluator/evaluator_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/parser/ast.cr src/starlark/evaluator/evaluator.cr spec/starlark/evaluator/evaluator_spec.cr
git commit -m "feat: add list and dict literals and indexing"
```

---

### Task 12: Built-in Functions

**Files:**
- Create: `src/starlark/evaluator/builtins.cr`
- Modify: `src/starlark/evaluator/evaluator.cr`
- Test: `spec/starlark/evaluator/builtins_spec.cr`

**Step 1: Write failing spec**

```crystal
require "spec"

describe Starlark::Evaluator do
  it "implements len()" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval("len([1, 2, 3])")
    result.as_int.should eq(3)
  end

  it "implements range()" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval("range(5)")
    result.type.should eq("list")
    result.as_list.size.should eq(5)
  end

  it "implements str()" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval("str(42)")
    result.as_string.should eq("42")
  end

  it "implements int()" do
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval(%(int("42")))
    result.as_int.should eq(42)
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/evaluator/builtins_spec.cr`
Expected: FAIL

**Step 3: Implement built-in functions**

Create `src/starlark/evaluator/builtins.cr`:

```crystal
require "../types/value"

module Starlark
  class BuiltinFunction
    @name : String
    @handler : Array(Value) -> Value

    def initialize(@name, &@handler : Array(Value) -> Value)
    end

    def call(args : Array(Value)) : Value
      @handler.call(args)
    end
  end

  module Builtins
    def self.register_all(evaluator : Evaluator)
      evaluator.register_builtin("len", ->len)
      evaluator.register_builtin("range", ->range)
      evaluator.register_builtin("str", ->str)
      evaluator.register_builtin("int", ->int)
      evaluator.register_builtin("bool", ->bool)
      evaluator.register_builtin("list", ->list)
      evaluator.register_builtin("dict", ->dict)
      evaluator.register_builtin("tuple", ->tuple)
    end

    def self.len(args : Array(Value)) : Value
      if args.size != 1
        raise "len() expects 1 argument, got #{args.size}"
      end

      arg = args[0]
      case arg.type
      when "string"
        Value.new(arg.as_string.size.to_i64)
      when "list"
        Value.new(arg.as_list.size.to_i64)
      when "dict"
        Value.new(arg.as_dict.size.to_i64)
      else
        raise "len() argument must be string, list, or dict, not #{arg.type}"
      end
    end

    def self.range(args : Array(Value)) : Value
      if args.size == 1
        stop = args[0].as_int.to_i
        Value.new((0...stop).map { |i| Value.new(i.to_i64) })
      elsif args.size == 2
        start = args[0].as_int.to_i
        stop = args[1].as_int.to_i
        Value.new((start...stop).map { |i| Value.new(i.to_i64) })
      elsif args.size == 3
        start = args[0].as_int.to_i
        stop = args[1].as_int.to_i
        step = args[2].as_int.to_i
        Value.new((start...stop).step(step).map { |i| Value.new(i.to_i64) })
      else
        raise "range() expects 1-3 arguments, got #{args.size}"
      end
    end

    def self.str(args : Array(Value)) : Value
      if args.size != 1
        raise "str() expects 1 argument, got #{args.size}"
      end

      arg = args[0]
      case arg.type
      when "NoneType"
        Value.new("None")
      when "bool"
        Value.new(arg.as_bool.to_s)
      when "int"
        Value.new(arg.as_int.to_s)
      when "string"
        arg  # Already a string
      else
        Value.new(arg.to_s)
      end
    end

    def self.int(args : Array(Value)) : Value
      if args.size != 1
        raise "int() expects 1 argument, got #{args.size}"
      end

      arg = args[0]
      case arg.type
      when "string"
        Value.new(arg.as_string.to_i64)
      when "bool"
        Value.new(arg.as_bool ? 1_i64 : 0_i64)
      when "int"
        arg  # Already an int
      else
        raise "int() argument must be string or bool, not #{arg.type}"
      end
    end

    def self.bool(args : Array(Value)) : Value
      if args.size != 1
        raise "bool() expects 1 argument, got #{args.size}"
      end

      Value.new(args[0].truth)
    end

    def self.list(args : Array(Value)) : Value
      if args.size == 0
        Value.new([] of Value)
      elsif args.size == 1
        arg = args[0]
        case arg.type
        when "string"
          Value.new(arg.as_string.chars.map { |c| Value.new(c.to_s) })
        when "list"
          arg  # Already a list
        else
          raise "list() argument must be string or list, not #{arg.type}"
        end
      else
        raise "list() expects 0-1 arguments, got #{args.size}"
      end
    end

    def self.dict(args : Array(Value)) : Value
      if args.size == 0
        Value.new(Hash(Value, Value).new)
      elsif args.size == 1
        arg = args[0]
        case arg.type
        when "list"
          # Convert list of pairs to dict
          dict = Hash(Value, Value).new
          arg.as_list.each do |pair|
            # pair should be a list of 2 elements
            pair_list = pair.as_list
            if pair_list.size != 2
              raise "dict() requires list of 2-element tuples"
            end
            dict[pair_list[0]] = pair_list[1]
          end
          Value.new(dict)
        else
          raise "dict() argument must be list, not #{arg.type}"
        end
      else
        raise "dict() expects 0-1 arguments, got #{args.size}"
      end
    end

    def self.tuple(args : Array(Value)) : Value
      # For now, tuples are just immutable lists
      # We'll implement proper freezing later
      list(args)
    end
  end
end
```

Update evaluator.cr to support function calls and builtins:

```crystal
    def initialize
      @globals = {} of String => Value
      @builtins = {} of String => Value
      Builtins.register_all(self)
    end

    def register_builtin(name : String, handler : Array(Value) -> Value)
      @builtins[name] = Value.new(handler)
    end

# In evaluate_expr, add:

      when AST::Call
        evaluate_call(expr)

# Add method:

    private def evaluate_call(expr : AST::Call) : Value
      func = evaluate_expr(expr.target)

      args = expr.arguments.map { |arg| evaluate_expr(arg) }

      # Check if it's a builtin (stored as proc)
      if func.is_a?(Proc)
        func.as(Array(Value) -> Value).call(args)
      else
        raise "Cannot call #{func.type}"
      end
    end
```

Add Call node to ast.cr:

```crystal
    class Call < Expr
      getter target : Expr
      getter arguments : Array(Expr)

      def initialize(@target, @arguments)
      end
    end
```

Update parser.cr to handle calls:

```crystal
# In parse_primary, add after LPAREN case or in parse_unary:

    private def parse_call(target : AST::Expr) : AST::Expr
      expect(:LPAREN)
      args = [] of AST::Expr

      if current_token.type != :RPAREN
        args << parse_expression
        while current_token.type == :COMMA
          advance
          break if current_token.type == :RPAREN
          args << parse_expression
        end
      end

      expect(:RPAREN)
      AST::Call.new(target, args)
    end

# Update parse_primary to check for calls after parsing primary:

    private def parse_primary : AST::Expr
      expr = parse_primary_expr

      while current_token.type == :LPAREN
        expr = parse_call(expr)
      end

      expr
    end

    private def parse_primary_expr : AST::Expr
      # ... existing code from parse_primary
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/evaluator/builtins_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/evaluator/builtins.cr src/starlark/evaluator/evaluator.cr src/starlark/parser/ast.cr src/starlark/parser/parser.cr spec/starlark/evaluator/builtins_spec.cr
git commit -m "feat: add built-in functions (len, range, str, int, bool, list, dict, tuple)"
```

---

## PHASE 4: INTEGRATION & POLISH

### Task 13: Crystal Integration API

**Files:**
- Modify: `src/starlark/evaluator/evaluator.cr`
- Test: `spec/starlark/evaluator/integration_spec.cr`

**Step 1: Write failing spec for integration API**

```crystal
require "spec"

describe Starlark::Evaluator do
  it "allows setting globals from Crystal" do
    evaluator = Starlark::Evaluator.new
    evaluator.set_global("VERSION", Starlark::Value.new("1.0.0"))

    result = evaluator.eval("VERSION")
    result.as_string.should eq("1.0.0")
  end

  it "allows registering custom builtins" do
    evaluator = Starlark::Evaluator.new
    evaluator.register_builtin("double", ->(args : Array(Starlark::Value)) {
      Starlark::Value.new(args[0].as_int * 2)
    })

    result = evaluator.eval("double(21)")
    result.as_int.should eq(42)
  end

  it "evaluates files" do
    File.write("/tmp/test.star", "x = 42\nx")
    evaluator = Starlark::Evaluator.new
    result = evaluator.eval_file("/tmp/test.star")
    result.as_int.should eq(42)
    File.delete("/tmp/test.star")
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/evaluator/integration_spec.cr`
Expected: FAIL

**Step 3: Implement integration API**

Add to evaluator.cr:

```crystal
    def set_global(name : String, value : Value)
      @globals[name] = value
    end

    def register_builtin(name : String, &handler : Array(Value) -> Value)
      @builtins[name] = Value.new(handler)
    end

    def eval_file(path : String) : Value
      source = File.read(path)
      parser = Parser.new(source)

      # Evaluate all statements in the file
      result = Value.none
      while @pos < parser.@tokens.size && !parser.eof?
        stmt = parser.parse_statement
        result = evaluate_stmt(stmt) || result
      end

      result
    end

    def eval_multi(source : String) : Value?
      parser = Parser.new(source)

      result = Value.none
      while @pos < parser.@tokens.size && !parser.eof?
        stmt = parser.parse_statement
        result = evaluate_stmt(stmt) || result
      end

      result
    end
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/evaluator/integration_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/evaluator/evaluator.cr spec/starlark/evaluator/integration_spec.cr
git commit -m "feat: add Crystal integration API"
```

---

### Task 14: Function Definitions and Closures

**Files:**
- Modify: `src/starlark/types/value.cr`
- Modify: `src/starlark/evaluator/evaluator.cr`
- Test: `spec/starlark/evaluator/functions_spec.cr`

**Step 1: Write failing spec**

```crystal
require "spec"

describe Starlark::Evaluator do
  it "defines and calls user functions" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_multi(<<-STARLARK)
      def add(a, b):
        return a + b
      x = add(1, 2)
      STARLARK

    evaluator.get_global("x").as_int.should eq(3)
  end

  it "supports closures" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_multi(<<-STARLARK)
      def make_adder(n):
        def adder(x):
          return x + n
        return adder
      add5 = make_adder(5)
      y = add5(3)
      STARLARK

    evaluator.get_global("y").as_int.should eq(8)
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/evaluator/functions_spec.cr`
Expected: FAIL

**Step 3: Implement function values and closures**

Add Function type to value.cr:

```crystal
  class Function
    getter name : String
    getter params : Array(String)
    getter body : Array(AST::Stmt)
    getter closure : Hash(String, Value)

    def initialize(@name, @params, @body, @closure = {} of String => Value)
    end
  end
```

Update evaluator.cr:

```crystal
    private def evaluate_def(stmt : AST::Def) : Value?
      func = Function.new(stmt.name, stmt.params, stmt.body, @globals.dup)
      @globals[stmt.name] = Value.new(func)
      nil
    end

# In evaluate_call, add function handling:

      when AST::Call
        func_val = evaluate_expr(expr.target)
        args = expr.arguments.map { |arg| evaluate_expr(arg) }

        if func_val.type == "function"
          call_user_function(func_val, args)
        elsif func_val.is_a?(Proc)
          func_val.as(Array(Value) -> Value).call(args)
        else
          raise "Cannot call #{func_val.type}"
        end

# Add method:

    private def call_user_function(func : Function, args : Array(Value)) : Value
      if args.size != func.params.size
        raise "Function #{func.name} expects #{func.params.size} arguments, got #{args.size}"
      end

      # Create new frame with closure as parent
      old_globals = @globals
      @globals = func.closure.dup

      # Bind parameters
      func.params.each_with_index do |param, i|
        @globals[param] = args[i]
      end

      # Execute function body
      result = Value.none
      func.body.each do |stmt|
        val = evaluate_stmt(stmt)
        if stmt.is_a?(AST::Return)
          result = val
          break
        end
      end

      # Restore globals
      @globals = old_globals

      result
    end
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/evaluator/functions_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/types/value.cr src/starlark/evaluator/evaluator.cr spec/starlark/evaluator/functions_spec.cr
git commit -m "feat: add user-defined functions and closures"
```

---

### Task 15: Freezing (Immutability)

**Files:**
- Modify: `src/starlark/types/value.cr`
- Modify: `src/starlark/evaluator/evaluator.cr`
- Test: `spec/starlark/evaluator/freezing_spec.cr`

**Step 1: Write failing spec**

```crystal
require "spec"

describe Starlark::Evaluator do
  it "freezes values after evaluation" do
    evaluator = Starlark::Evaluator.new
    evaluator.eval_multi(<<-STARLARK)
      x = [1, 2, 3]
      STARLARK

    list_val = evaluator.get_global("x")

    # After evaluation, attempting to modify should fail
    expect_raises(Exception, "Cannot modify frozen value") do
      list_val.as_list << Starlark::Value.new(4)
    end
  end
end
```

**Step 2: Run spec to verify it fails**

Run: `crystal spec spec/starlark/evaluator/freezing_spec.cr`
Expected: FAIL

**Step 3: Implement freezing**

Update value.cr:

```crystal
  class Value
    getter type : String
    getter frozen : Bool = false

    # ... existing code ...

    def freeze!
      @frozen = true

      case @value
      when Array
        @value.each(&.freeze!)
      when Hash
        @value.each { |k, v| k.freeze!; v.freeze! }
      end

      self
    end

    def as_list : Array(Value)
      if @frozen
        raise "Cannot modify frozen value"
      end
      @value.as(Array(Value))
    end

    def as_dict : Hash(Value, Value)
      if @frozen
        raise "Cannot modify frozen value"
      end
      @value.as(Hash(Value, Value))
    end
  end
```

Update evaluator.cr:

```crystal
    def eval_file(path : String) : Value
      source = File.read(path)
      parser = Parser.new(source)

      result = Value.none
      while @pos < parser.@tokens.size && !parser.eof?
        stmt = parser.parse_statement
        result = evaluate_stmt(stmt) || result
      end

      # Freeze all globals
      @globals.each_value(&.freeze!)

      result
    end
```

**Step 4: Run spec to verify it passes**

Run: `crystal spec spec/starlark/evaluator/freezing_spec.cr`
Expected: PASS

**Step 5: Commit**

```bash
git add src/starlark/types/value.cr src/starlark/evaluator/evaluator.cr spec/starlark/evaluator/freezing_spec.cr
git commit -m "feat: add value freezing for immutability"
```

---

### Task 16: Linting and Final Polish

**Files:**
- All source files

**Step 1: Run linter and fix issues**

Run: `ameba --fix`

Expected: Auto-fix any style issues

**Step 2: Build project**

Run: `shards build`

Expected: Successful build with no errors

**Step 3: Run all tests**

Run: `crystal spec`

Expected: All tests pass

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: fix linting issues and ensure all tests pass"
```

---

## SUMMARY

This plan implements a complete Starlark interpreter in Crystal with:

**Phase 1: Lexer** - Tokenizes Starlark source code
- Token type system
- Keyword and identifier tokenization
- Literals (numbers, strings, booleans, None)
- Operators and punctuation

**Phase 2: Parser** - Builds AST from tokens
- AST node base classes
- Expression parsing (literals, identifiers, binary ops)
- Statement parsing (assignment, if, for, return, def)

**Phase 3: Evaluator** - Executes AST
- Value type system (None, bool, int, string, list, dict)
- Expression evaluation
- Statement evaluation
- List and dict literals
- Built-in functions

**Phase 4: Integration & Polish**
- Crystal integration API
- User-defined functions and closures
- Freezing for immutability
- Linting and testing

**Total estimated tasks:** 16
**Follow TDD:** Write failing test → implement → verify pass → commit
**Frequent commits:** Each feature/fix gets its own commit
