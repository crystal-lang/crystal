require "./repl"

# Instructions together with their mapping back to AST nodes.
class Crystal::Repl::CompiledInstructions
  # The actual bytecode.
  getter instructions : Array(UInt8)

  # The nodes to refer from the instructions (by index)
  getter nodes : Hash(Int32, ASTNode)

  def initialize
    @instructions = [] of UInt8
    @nodes = {} of Int32 => ASTNode
  end
end
