struct LLVM::FunctionCollection
  def initialize(@mod)
  end

  def add(name, arg_types, ret_type, varargs = false)
    fun_type = LLVM.function_type(arg_types, ret_type, varargs)
    func = LibLLVM.add_function(@mod.llvm_module, name, fun_type)
    Function.new(func)
  end

  def add(name, arg_types, ret_type, varargs = false)
    func = add(name, arg_types, ret_type, varargs)
    yield func
    func
  end

  def [](name)
    self[name]?.not_nil!
  end

  def []?(name)
    func = LibLLVM.get_named_function(@mod.llvm_module, name)
    func ? Function.new(func) : nil
  end
end
