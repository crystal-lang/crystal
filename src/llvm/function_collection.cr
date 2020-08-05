struct LLVM::FunctionCollection
  def initialize(@mod : Module)
  end

  def add(name, arg_types : Array(LLVM::Type), ret_type, varargs = false)
    # check_types_context(name, arg_types, ret_type)

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
    func || raise "Undefined llvm function: #{name}"
  end

  def []?(name)
    func = LibLLVM.get_named_function(@mod, name)
    func ? Function.new(func) : nil
  end

  def each : Nil
    f = LibLLVM.get_first_function(@mod)
    while f
      yield LLVM::Function.new f
      f = LibLLVM.get_next_function(f)
    end
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
