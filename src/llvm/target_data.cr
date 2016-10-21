struct LLVM::TargetData
  def initialize(@unwrap : LibLLVM::TargetDataRef)
  end

  def size_in_bits(type)
    LibLLVM.size_of_type_in_bits(self, type)
  end

  def size_in_bytes(type)
    size_in_bits(type) / 8
  end

  def abi_size(type)
    LibLLVM.abi_size_of_type(self, type)
  end

  def abi_alignment(type)
    LibLLVM.abi_alignment_of_type(self, type)
  end

  def to_unsafe
    @unwrap
  end

  def offset_of_element(struct_type, element)
    LibLLVM.offset_of_element(self, struct_type, element)
  end

  def to_data_layout_string
    String.new(LibLLVM.copy_string_rep_of_target_data(self))
  end
end
