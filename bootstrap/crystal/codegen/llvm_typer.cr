module Crystal
  class LLVMTyper
    def llvm_type(type : PrimitiveType)
      type.llvm_type
    end

    def llvm_type(type)
      LLVM::Void
    end
  end
end
