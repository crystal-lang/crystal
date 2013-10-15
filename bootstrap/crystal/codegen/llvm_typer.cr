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

    def llvm_type(type : InstanceVarContainer)
      LLVM::PointerType.new(llvm_struct_type(type))
    end

    def llvm_type(type : Metaclass)
      LLVM::Int64
    end

    def llvm_type(type : GenericClassInstanceMetaclass)
      LLVM::Int64
    end

    def llvm_type(type)
      raise "Bug: called llvm_type for #{type}"
    end

    def llvm_struct_type(type : InstanceVarContainer)
      @struct_types.fetch_or_assign(type) do
        struct = LLVM::StructType.new type.llvm_name
        struct.element_types = type.all_instance_vars.values.map { |var| llvm_embedded_type(var.type) }
        struct
      end
    end

    def llvm_struct_type(type)
      raise "Bug: called llvm_struct_type for #{type}"
    end

    def llvm_arg_type(type : PrimitiveType)
      type.llvm_type
    end

    def llvm_arg_type(type : InstanceVarContainer)
      llvm_type type
    end

    def llvm_arg_type(type : Metaclass)
      llvm_type type
    end

    def llvm_arg_type(type : GenericClassInstanceMetaclass)
      llvm_type type
    end

    def llvm_arg_type(type)
      raise "Bug: called llvm_arg_type for #{type}"
    end

    def llvm_embedded_type(type)
      llvm_type type
    end
  end
end
