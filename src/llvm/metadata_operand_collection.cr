struct LLVM::MetadataOperandCollection
  @operands = Array(Value).new

  def initialize(@mod : Module)
  end

  def add(name : String, value : Value) : Value
    # check_node_context(value)

    LibLLVM.add_named_metadata_operand(@mod, name, value)
    @operands << value
    value
  end

  # The next lines are for ease debugging when metadata nodes
  # are incorrectly used across contexts.

  # private def check_node_context(node)
  #   if @mod.context != node.context
  #     Context.wrong(@mod.context, node.context, "wrong context for MDNode #{name} in #{@mod.name}")
  #   end
  # end
end
