module Crystal
  class LLVMTyper
    def llvm_type(type : PrimitiveType)
      type.llvm_type
    end

    def llvm_type(type : Metaclass)
      LLVM::Int64
    end

    def llvm_type(type)
      raise "BUG: called llvm_type for #{type}"
    end

    def llvm_arg_type(type : PrimitiveType)
      type.llvm_type
    end

    def llvm_arg_type(type : Metaclass)
      llvm_type type
    end

    def llvm_arg_type(type)
      raise "BUG: called llvm_arg_type for #{type}"
    end
  end
end
