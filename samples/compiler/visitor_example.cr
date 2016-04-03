# This is a small sample on how to use a Crystal::Visitor
# to traverse an AST.
#
# Here we count the number of NumberLiterals in a program.

# Use `require "compiler/crystal/syntax"` in your programs
require "../../src/compiler/crystal/syntax"

class Counter < Crystal::Visitor
  getter count

  def initialize
    @count = 0
  end

  def visit(node : Crystal::NumberLiteral)
    @count += 1
  end

  def visit(node : Crystal::ASTNode)
    # true: we want to the visitor to visit node's children
    true
  end
end

nodes = Crystal::Parser.parse("hello(99, 114, 121, 115, 116, 97, 108)")

counter = Counter.new
nodes.accept counter
puts counter.count
