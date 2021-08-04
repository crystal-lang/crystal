require "./repl"

# Instructions together with their mapping back to AST nodes.
class Crystal::Repl::CompiledInstructions
  record Rescue, start_index : Int32, end_index : Int32, exception_types : Array(Type), jump_index : Int32

  # The actual bytecode.
  getter instructions : Array(UInt8) = [] of UInt8

  # The nodes to refer from the instructions (by index)
  getter nodes : Hash(Int32, ASTNode) = {} of Int32 => ASTNode

  getter rescues : Array(Rescue)?

  def add_rescue(start_index : Int32, end_index : Int32, exception_types : Array(Type), jump_index : Int32)
    rescues = @rescues ||= [] of Rescue
    rescues << Rescue.new(start_index, end_index, exception_types, jump_index)
  end
end
