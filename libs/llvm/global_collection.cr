struct LLVM::GlobalCollection
  def initialize(@mod)
  end

  def add(type, name)
    LibLLVM.add_global(@mod, type, name)
  end

  def []?(name)
    global = LibLLVM.get_named_global(@mod, name)
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
