struct LLVM::ParameterCollection
  include Indexable(LLVM::Value)

  def initialize(@function : Function)
  end

  def size
    @function.function_type.params_size
  end

  def to_a
    param_size = size()
    Array(LLVM::Value).build(param_size) do |buffer|
      LibLLVM.get_params(@function, buffer.as(LibLLVM::ValueRef*))
      param_size
    end
  end

  def unsafe_fetch(index : Int)
    Value.new LibLLVM.get_param(@function, index)
  end

  def types
    @function.function_type.params_types
  end
end
