struct LLVM::GlobalCollection
  def initialize(@mod : Module)
  end

  def add(type, name)
    # check_type_context(type, name)

    Value.new LibLLVM.add_global(@mod, type, name)
  end

  def []?(name)
    global = LibLLVM.get_named_global(@mod, name)
    global ? Value.new(global) : nil
  end

  def [](name)
    global = self[name]?
    if global
      global
    else
      raise "Global not found: #{name}"
    end
  end

  # The next lines are for ease debugging when a types/values
  # are incorrectly used across contexts.

  # private def check_type_context(type, name)
  #   if @mod.context != type.context
  #     Context.wrong(@mod.context, type.context, "wrong context for global #{name} in #{@mod.name}, type #{type}")
  #   end
  # end
end
