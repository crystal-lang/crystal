struct LLVM::GenericValue
  def initialize(value)
    @value = value
  end

  def to_i
    LibLLVM.generic_value_to_int(@value, 1)
  end

  def to_b
    to_i != 0
  end

  def to_f32
    LibLLVM.generic_value_to_float(LLVM::Float, @value)
  end

  def to_f64
    LibLLVM.generic_value_to_float(LLVM::Double, @value)
  end

  def to_string
    to_pointer as String
  end

  def to_pointer
    LibLLVM.generic_value_to_pointer(@value)
  end
end
