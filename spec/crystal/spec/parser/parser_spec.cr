#!/usr/bin/env bin/crystal -run
require "spec"
require "../../../../bootstrap/crystal/parser"
require "../../../../bootstrap/crystal/to_s"

include Crystal

class Numeric
  def int
    IntLiteral.new to_s
  end

  def long
    LongLiteral.new to_s
  end

  def float
    FloatLiteral.new to_f.to_s
  end

  def double
    DoubleLiteral.new to_d.to_s
  end
end

class Bool
  def bool
    BoolLiteral.new self
  end
end

class Array
  def array
    ArrayLiteral.new self
  end
end

class String
  def var
    Var.new self
  end

  def arg
    Arg.new self
  end
end

def it_parses(string, expected_node)
  it "parses #{string}" do
    node = Parser.parse(string)
    node.should eq(Expressions.from expected_node)
  end
end

include Crystal

describe "Parser" do
  it_parses "nil", NilLiteral.new

  it_parses "true", true.bool
  it_parses "false", false.bool

  it_parses "1", 1.int
  it_parses "+1", 1.int
  it_parses "-1", -1.int

  it_parses "1L", 1.long
  it_parses "+1L", 1.long
  it_parses "-1L", -1.long

  it_parses "1.0", 1.0.double
  it_parses "+1.0", 1.0.double
  it_parses "-1.0", -1.0.double

  it_parses "1.0f", 1.0.float
  it_parses "+1.0f", 1.0.float
  it_parses "-1.0f", -1.0.float

  it_parses "'a'", CharLiteral.new("a")

  it_parses "\"foo\"", StringLiteral.new("foo")
  it_parses "\"\"", StringLiteral.new("")

  it_parses ":foo", SymbolLiteral.new("foo")

  it_parses "[]", [].array
  it_parses "[1, 2]", [1.int, 2.int].array
  it_parses "[\n1, 2]", [1.int, 2.int].array
  it_parses "[1,\n 2,]", [1.int, 2.int].array

  it_parses "1 + 2", Call.new(1.int, "+", [2.int])
  it_parses "1 +\n2", Call.new(1.int, "+", [2.int])
  it_parses "1 +2", Call.new(1.int, "+", [2.int])
  it_parses "1 -2", Call.new(1.int, "-", [2.int])
  it_parses "1 +2.0", Call.new(1.int, "+", [2.double])
  it_parses "1 -2.0", Call.new(1.int, "-", [2.double])
  it_parses "1 +2L", Call.new(1.int, "+", [2.long])
  it_parses "1 -2L", Call.new(1.int, "-", [2.long])
  it_parses "1\n+2", [1.int, 2.int]
  it_parses "1;+2", [1.int, 2.int]
  it_parses "1 - 2", Call.new(1.int, "-", [2.int])
  it_parses "1 -\n2", Call.new(1.int, "-", [2.int])
  it_parses "1\n-2", [1.int, -2.int]
  it_parses "1;-2", [1.int, -2.int]
  it_parses "1 * 2", Call.new(1.int, "*", [2.int])
  it_parses "1 * -2", Call.new(1.int, "*", [-2.int])
  it_parses "2 * 3 + 4 * 5", Call.new(Call.new(2.int, "*", [3.int]), "+", [Call.new(4.int, "*", [5.int])])
  it_parses "1 / 2", Call.new(1.int, "/", [2.int])
  it_parses "1 / -2", Call.new(1.int, "/", [-2.int])
  it_parses "2 / 3 + 4 / 5", Call.new(Call.new(2.int, "/", [3.int]), "+", [Call.new(4.int, "/", [5.int])])
  it_parses "2 * (3 + 4)", Call.new(2.int, "*", [Call.new(3.int, "+", [4.int])])

  it_parses "!1", Call.new(1.int, "!@")
  it_parses "1 && 2", Call.new(1.int, "&&", [2.int])
  it_parses "1 || 2", Call.new(1.int, "||", [2.int])

  it_parses "1 <=> 2", Call.new(1.int, "<=>", [2.int])

  it_parses "a = 1", Assign.new("a".var, 1.int)
  it_parses "a = b = 2", Assign.new("a".var, Assign.new("b".var, 2.int))

  # it_parses "a, b = 1, 2", MultiAssign.new(["a".var, "b".var], [1.int, 2.int])
  # it_parses "a, b = 1", MultiAssign.new(["a".var, "b".var], [1.int])
  # it_parses "a = 1, 2", MultiAssign.new(["a".var], [1.int, 2.int])

  it_parses "def foo\n1\nend", Def.new("foo", [], [1.int])
  it_parses "def downto(n)\n1\nend", Def.new("downto", ["n".arg], [1.int])
  it_parses "def foo ; 1 ; end", Def.new("foo", [], [1.int])
  it_parses "def foo; end", Def.new("foo", [], nil)
  it_parses "def foo(var); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(\nvar); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(\nvar\n); end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo(var1, var2); end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo(\nvar1\n,\nvar2\n)\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo var; end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo var\n end", Def.new("foo", ["var".arg], nil)
  it_parses "def foo var1, var2\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo var1,\nvar2\n end", Def.new("foo", ["var1".arg, "var2".arg], nil)
  it_parses "def foo; 1; 2; end", Def.new("foo", [], [1.int, 2.int])
  it_parses "def foo=(value); end", Def.new("foo=", ["value".arg], [])
end
