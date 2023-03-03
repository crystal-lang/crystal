struct LLVM::FunctionCollection
  # two distinct `LLVM::Module`s or `LLVM::Function`s in Crystal may refer to
  # the same LLVM object, so this association must not be done as instance
  # variables of those Crystal types
  # FIXME: keep track of things elsewhere!
  @@func_types = {} of {LibLLVM::ModuleRef, LibLLVM::ValueRef} => LLVM::Type

  def initialize(@mod : Module)
  end

  def add(name, arg_types : Array(LLVM::Type), ret_type, varargs = false)
    # check_types_context(name, arg_types, ret_type)

    fun_type = LLVM::Type.function(arg_types, ret_type, varargs)
    func = LibLLVM.add_function(@mod, name, fun_type)
    @@func_types[{@mod.to_unsafe, func}] = fun_type
    Function.new(func, fun_type)
  end

  def add(name, arg_types : Array(LLVM::Type), ret_type, varargs = false)
    func = add(name, arg_types, ret_type, varargs)
    yield func
    func
  end

  def [](name)
    func = self[name]?
    func || raise "Undefined llvm function: #{name}"
  end

  def []?(name)
    func = LibLLVM.get_named_function(@mod, name)
    func ? func_from_llvm(func) : nil
  end

  def each : Nil
    f = LibLLVM.get_first_function(@mod)
    while f
      yield func_from_llvm(f)
      f = LibLLVM.get_next_function(f)
    end
  end

  private def func_from_llvm(f : LibLLVM::ValueRef) : Function
    Function.new(f, @@func_types[{@mod.to_unsafe, f}])
  end

  # The next lines are for ease debugging when a types/values
  # are incorrectly used across contexts.

  # private def check_types_context(name, arg_types, ret_type)
  #   ctx = @mod.context

  #   arg_types.each_with_index do |arg_type, index|
  #     if arg_type.context != ctx
  #       Context.wrong(ctx, arg_type.context, "wrong context for function #{name} in #{@mod.name}, index #{index}, type #{arg_type}")
  #     end
  #   end

  #   if ret_type.context != ctx
  #     Context.wrong(ctx, ret_type.context, "wrong context for function #{name} in #{@mod.name}, return type #{ret_type}")
  #   end
  # end
end
