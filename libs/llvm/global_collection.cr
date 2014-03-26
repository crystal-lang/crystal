struct LLVM::GlobalCollection
  def initialize(@mod)
  end

  def add(type, name)
    LibLLVM.add_global(@mod.llvm_module, type, name)
  end

  def []?(name)
    global = LibLLVM.get_named_global(@mod.llvm_module, name)
    global ? global : nil
  end

  def [](name)
    global = self[name]?
    if global
      global
    else
      raise "Global not found: #{name}"
    end
  end
end
