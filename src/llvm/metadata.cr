struct LLVM::Metadata
  def initialize(@unwrap : LibLLVM::MetadataRef)
  end

  def to_unsafe
    @unwrap
  end

  {% if LibLLVM.has_method?(:print_metadata_to_string) %}
    # This override is only available on LLVM 24 or above.
    def inspect(io : IO) : Nil
      LLVM.to_io(LibLLVM.print_metadata_to_string(self), io)
    end
  {% end %}
end
