#!/usr/bin/env bin/crystal -run
require "spec"
require "../../../../bootstrap/crystal/parser"

class Bool
  def bool
    Crystal::BoolLiteral.new self
  end
end

class Int
  def int
    Crystal::IntLiteral.new self.to_s
  end

  def long
    Crystal::LongLiteral.new self.to_s
  end
end

class Float
  def float
    Crystal::FloatLiteral.new self.to_s
  end
end

class Array
  def array
    Crystal::ArrayLiteral.new self
  end
end

def it_parses(string, expected_node)
  it "parses #{string}" do
    node = Crystal::Parser.parse(string)
    node.should eq(Crystal::Expressions.from expected_node)
  end
end

describe "Parser" do
  it_parses "nil", Crystal::NilLiteral.new

  it_parses "true", true.bool
  it_parses "false", false.bool

  it_parses "1", 1.int
  it_parses "+1", 1.int
  it_parses "-1", -1.int

  it_parses "1L", 1.long
  it_parses "+1L", 1.long
  it_parses "-1L", -1.long

  it_parses "1.0", 1.0.float
  it_parses "+1.0", 1.0.float
  it_parses "-1.0", -1.0.float

  it_parses "'a'", Crystal::CharLiteral.new('a'.ord)

  it_parses "\"foo\"", Crystal::StringLiteral.new("foo")
  it_parses "\"\"", Crystal::StringLiteral.new("")

  it_parses ":foo", Crystal::SymbolLiteral.new("foo")

  it_parses "[]", [].array
  it_parses "[1, 2]", [1.int, 2.int].array
  it_parses "[\n1, 2]", [1.int, 2.int].array
  it_parses "[1,\n 2,]", [1.int, 2.int].array

  it_parses "1 + 2", Crystal::Call.new(1.int, "+", [2.int])
end
