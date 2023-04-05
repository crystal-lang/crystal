struct LLVM::ParameterCollection
  include Indexable(LLVM::Value)

  def initialize(@function : Function)
  end

  def size
    LibLLVM.get_count_params(@function).to_i
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
    to_a.map(&.type)
  end
end
