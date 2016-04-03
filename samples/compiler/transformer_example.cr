# This is a small sample on how to use a Crystal::Transformer
# to transform source code.
#
# Here we transform all number literals with their char
# equivalent using `chr`.

# Use `require "compiler/crystal/syntax"` in your programs
require "../../src/compiler/crystal/syntax"

class Charify < Crystal::Transformer
  def transform(node : Crystal::NumberLiteral)
    Crystal::CharLiteral.new(node.value.to_i.chr)
  end
end

nodes = Crystal::Parser.parse("hello(99, 114, 121, 115, 116, 97, 108)")
puts nodes.transform(Charify.new)
