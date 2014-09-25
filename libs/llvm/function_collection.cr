struct LLVM::FunctionCollection
  def initialize(@mod)
  end

  def add(name, arg_types : Array(LLVM::Type), ret_type, varargs = false)
    fun_type = LLVM::Type.function(arg_types, ret_type, varargs)
    func = LibLLVM.add_function(@mod, name, fun_type)
    Function.new(func)
  end

  def add(name, arg_types : Array(LLVM::Type), ret_type, varargs = false)
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

  def each
    f = LibLLVM.get_first_function(@mod)
    while f
      yield LLVM::Function.new f
      f = LibLLVM.get_next_function(f)
    end
    self
  end
end
