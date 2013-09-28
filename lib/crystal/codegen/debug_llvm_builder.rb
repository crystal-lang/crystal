module Crystal
  class DebugLLVMBuilder
    def initialize(builder, codegen)
      @builder = builder
      @codegen = codegen
      @dbg_kind = LLVM::C.get_md_kind_id("dbg", 3)
    end

    undef :load
    undef :select

    def method_missing(name, *args)
      ret = @builder.send name, *args
      if ret.is_a?(LLVM::Value) && !ret.constant? && !ret.is_a?(LLVM::BasicBlock)
        md = @codegen.dbg_metadata
        LLVM::C.set_metadata ret, @dbg_kind, md if md rescue nil
      end
      ret
    end
  end
end
