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
end
