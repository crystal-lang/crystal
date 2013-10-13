require "../types"
require "../llvm"


module Crystal
  class LLVMTyper
    def initialize
      @struct_types = {} of Type => LLVM::Type
    end

    def llvm_type(type : PrimitiveType)
      type.llvm_type
    end

    def llvm_type(type : InheritableClass)
      LLVM::PointerType.new(llvm_struct_type(type))
    end

    def llvm_type(type : Metaclass)
      LLVM::Int64
    end

    def llvm_type(type)
      raise "BUG: called llvm_type for #{type}"
    end

    def llvm_struct_type(type : InheritableClass)
      @struct_types.fetch_or_assign(type) do
        struct = LLVM::StructType.new type.llvm_name
        struct.element_types = [] of LLVM::Type
        struct
      end
    end

    def llvm_struct_type(type)
      raise "BUG: called llvm_struct_type for #{type}"
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
