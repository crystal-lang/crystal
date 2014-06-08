struct LLVM::FunctionCollection
  def initialize(@mod)
  end

  def add(name, arg_types, ret_type, varargs = false)
    fun_type = LLVM.function_type(arg_types, ret_type, varargs)
    func = LibLLVM.add_function(@mod, name, fun_type)
    Function.new(func)
  end

  def add(name, arg_types, ret_type, varargs = false)
    func = add(name, arg_types, ret_type, varargs)
    yield func
    func
  end

  def [](name)
    func = self[name]?
    func || raise "undefined llvm function: #{name}"
  end

  def []?(name)
    func = LibLLVM.get_named_function(@mod, name)
    func ? Function.new(func) : nil
  end
end
