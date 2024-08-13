{% skip_file if LibLLVM::IS_LT_110 %}

@[Experimental("The C API wrapped by this type is marked as experimental by LLVM.")]
class LLVM::Orc::JITDylib
  protected def initialize(@unwrap : LibLLVM::OrcJITDylibRef)
  end

  def to_unsafe
    @unwrap
  end

  def link_symbols_from_current_process : Nil
    prefix = {% if flag?(:darwin) %} '_'.ord.to_u8! {% else %} 0_u8 {% end %}
    LLVM.assert LibLLVM.orc_create_dynamic_library_search_generator_for_process(out dg, prefix, nil, nil)
    LibLLVM.orc_jit_dylib_add_generator(self, dg)
  end
end
