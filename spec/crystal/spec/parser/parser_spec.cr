#!/usr/bin/env bin/crystal -run
require "spec"
require "../../../../bootstrap/crystal/parser"

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
end
