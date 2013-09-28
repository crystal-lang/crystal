module Crystal
  class LLVMTyper
    def llvm_type(type : PrimitiveType)
      type.llvm_type
    end

    def llvm_type(type : Nil)
      raise "BUG: called llvm_type for nil"
    end

    def llvm_type(type)
      LLVM::Void
    end

    def llvm_arg_type(type : PrimitiveType)
      type.llvm_type
    end

    def llvm_arg_type(type)
      LLVM::Void
    end

    def llvm_arg_type(type : Nil)
      raise "BUG: called llvm_arg_type for nil"
    end
  end
end
