require "spec"
require "../../src/compiler/crystal/syntax"

include Crystal

struct Number
  def int32
    NumberLiteral.new to_s, :i32
  end

  def int64
    NumberLiteral.new to_s, :i64
  end

  def int128
    NumberLiteral.new to_s, :i128
  end

  def uint128
    NumberLiteral.new to_s, :u128
  end

  def float32
    NumberLiteral.new to_f32.to_s, :f32
  end

  def float64
    NumberLiteral.new to_f64.to_s, :f64
  end
end

struct Bool
  def bool
    BoolLiteral.new self
  end
end

class Array
  def array
    ArrayLiteral.new self
  end

  def array_of(type)
    ArrayLiteral.new self, type
  end

  def path
    Path.new self
  end
end

class String
  def var
    Var.new self
  end

  def arg(default_value = nil, restriction = nil)
    Arg.new self, default_value: default_value, restriction: restriction
  end

  def call
    Call.new nil, self
  end

  def call(args : Array)
    Call.new nil, self, args
  end

  def call(arg : ASTNode)
    Call.new nil, self, [arg] of ASTNode
  end

  def call(arg1 : ASTNode, arg2 : ASTNode)
    Call.new nil, self, [arg1, arg2] of ASTNode
  end

  def path(global = false)
    Path.new self, global
  end

  def instance_var
    InstanceVar.new self
  end

  def class_var
    ClassVar.new self
  end

  def string
    StringLiteral.new self
  end

  def string_interpolation
    StringInterpolation.new([self.string] of ASTNode)
  end

  def float32
    NumberLiteral.new self, :f32
  end

  def float64
    NumberLiteral.new self, :f64
  end

  def symbol
    SymbolLiteral.new self
  end

  def static_array_of(size : Int)
    static_array_of NumberLiteral.new(size)
  end

  def static_array_of(size : ASTNode)
    Generic.new(Path.global("StaticArray"), [path, size] of ASTNode)
  end

  def macro_literal
    MacroLiteral.new(self)
  end
end

class Crystal::ASTNode
  def pointer_of
    Generic.new(Path.global("Pointer"), [self] of ASTNode)
  end

  def splat
    Splat.new(self)
  end
end

def assert_syntax_error(str, message = nil, line = nil, column = nil, metafile = __FILE__, metaline = __LINE__, metaendline = __END_LINE__)
  it "says syntax error on #{str.inspect}", metafile, metaline, metaendline do
    begin
      parse str
      fail "Expected SyntaxException to be raised", metafile, metaline
    rescue ex : SyntaxException
      if message
        unless ex.message.not_nil!.includes?(message.not_nil!)
          fail "Expected message to include #{message.inspect} but got #{ex.message.inspect}", metafile, metaline
        end
      end
      if line
        unless ex.line_number == line
          fail "Expected line number to be #{line} but got #{ex.line_number}", metafile, metaline
        end
      end
      if column
        unless ex.column_number == column
          fail "Expected column number to be #{column} but got #{ex.column_number}", metafile, metaline
        end
      end
    end
  end
end

def parse(string, wants_doc = false)
  parser = Parser.new(string)
  parser.wants_doc = wants_doc
  parser.parse
end
