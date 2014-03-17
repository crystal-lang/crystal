module Crystal
  class DebugLLVMBuilder < CrystalLLVMBuilder
    def initialize(@builder, @codegen)
      super
      @dbg_kind = LibLLVM.get_md_kind_id("dbg", 3_u32)
    end

    def wrap(value)
      if value.is_a?(LibLLVM::ValueRef) && !LLVM.constant?(value) && !value.is_a?(LibLLVM::BasicBlockRef)
        if md = @codegen.dbg_metadata
          # puts "DUMP"
          # LLVM.dump md
          LibLLVM.set_metadata(value, @dbg_kind, md) rescue nil
          # LLVM.dump value
        end
      end
      value
    end
  end
end
