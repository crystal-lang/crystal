class LLVM::GenericValue
  def initialize(@unwrap : LibLLVM::GenericValueRef, @context : LLVM::Context)
  end

  def to_i
    LibLLVM.generic_value_to_int(self, 1)
  end

  def to_u64
    to_i
  end

  def to_b
    to_i != 0
  end

  def to_f32
    LibLLVM.generic_value_to_float(@context.float, self)
  end

  def to_f64
    LibLLVM.generic_value_to_float(@context.double, self)
  end

  def to_string
    to_pointer.as(String)
  end

  def to_pointer
    LibLLVM.generic_value_to_pointer(self)
  end

  def to_unsafe
    @unwrap
  end

  def finalize
    LibLLVM.dispose_generic_value(@unwrap)
  end
end
