module Crystal
  class LLVMTyper
    def llvm_type(type : PrimitiveType)
      type.llvm_type
    end

    def llvm_arg_type(type : PrimitiveType)
      type.llvm_type
    end

    def llvm_type(type)
      LLVM::Void
    end

    def llvm_arg_type(type)
      LLVM::Void
    end
  end
end
