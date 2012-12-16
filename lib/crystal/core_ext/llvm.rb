class LLVM::GenericValue
  def to_string
    to_ptr.read_pointer.read_string
  end
end