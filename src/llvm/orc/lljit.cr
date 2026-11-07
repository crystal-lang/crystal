{% skip_file if LibLLVM::IS_LT_110 %}

@[Experimental("The C API wrapped by this type is marked as experimental by LLVM.")]
class LLVM::Orc::LLJIT
  protected def initialize(@unwrap : LibLLVM::OrcLLJITRef)
  end

  def self.new(builder : LLJITBuilder)
    builder.take_ownership { raise "Failed to take ownership of LLVM::Orc::LLJITBuilder" }
    LLVM.assert LibLLVM.orc_create_lljit(out unwrap, builder)
    new(unwrap)
  end

  def to_unsafe
    @unwrap
  end

  def dispose : Nil
    LLVM.assert LibLLVM.orc_dispose_lljit(self)
    @unwrap = LibLLVM::OrcLLJITRef.null
  end

  def finalize
    if @unwrap
      LibLLVM.orc_dispose_lljit(self)
    end
  end

  def main_jit_dylib : JITDylib
    JITDylib.new(LibLLVM.orc_lljit_get_main_jit_dylib(self))
  end

  def global_prefix : Char
    LibLLVM.orc_lljit_get_global_prefix(self).unsafe_chr
  end

  def add_llvm_ir_module(dylib : JITDylib, tsm : ThreadSafeModule) : Nil
    tsm.take_ownership { raise "Failed to take ownership of LLVM::Orc::ThreadSafeModule" }
    LLVM.assert LibLLVM.orc_lljit_add_llvm_ir_module(self, dylib, tsm)
  end

  def add_object_file(dylib : JITDylib, object : MemoryBuffer) : Nil
    object.take_ownership { raise "Failed to take ownership of LLVM::MemoryBuffer" }
    obj_layer = LibLLVM.orc_lljit_get_obj_linking_layer(self)
    LLVM.assert LibLLVM.orc_object_layer_add_object_file(obj_layer, dylib, object)
  end

  def lookup(name : String) : Void*
    LLVM.assert LibLLVM.orc_lljit_lookup(self, out address, name.check_no_null_byte)
    Pointer(Void).new(address)
  end
end
