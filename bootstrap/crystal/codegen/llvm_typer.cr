require "../types"
require "../llvm"

module Crystal
  class LLVMTyper
    def initialize
      @cache = {} of Type => LibLLVM::TypeRef
      @struct_cache = {} of Type => LibLLVM::TypeRef
      @arg_cache = {} of Type => LibLLVM::TypeRef
      @embedded_cache = {} of Type => LibLLVM::TypeRef

      target = LLVM::Target.first
      machine = target.create_target_machine("i686-unknown-linux").not_nil!
      @layout = machine.data_layout.not_nil!
    end

    def llvm_type(type)
      @cache[type] ||= create_llvm_type(type)
    end

    def create_llvm_type(type : PrimitiveType)
      type.llvm_type
    end

    def create_llvm_type(type : InstanceVarContainer)
      LLVM.pointer_type(llvm_struct_type(type))
    end

    def create_llvm_type(type : Metaclass)
      LLVM::Int64
    end

    def create_llvm_type(type : GenericClassInstanceMetaclass)
      LLVM::Int64
    end

    def create_llvm_type(type : PointerInstanceType)
      pointed_type = llvm_embedded_type type.var.type
      pointed_type = LLVM::Int8 if pointed_type == LLVM::Void
      LLVM.pointer_type(pointed_type)
    end

    def create_llvm_type(type : UnionType)
      max_size = 0
      type.union_types.each do |subtype|
        size = size_of(llvm_type(subtype))
        max_size = size if size > max_size
      end
      max_size /= 4
      max_size = 1 if max_size == 0

      llvm_value_type = LLVM.array_type(LLVM::Int32, max_size)
      LLVM.struct_type(type.llvm_name, [LLVM::Int32, llvm_value_type])
    end

    def create_llvm_type(type : CStructType)
      LLVM.pointer_type(llvm_struct_type(type))
    end

    def create_llvm_type(type : CUnionType)
      LLVM.pointer_type(llvm_struct_type(type))
    end

    def create_llvm_type(type)
      raise "Bug: called create_llvm_type for #{type}"
    end

    def llvm_struct_type(type)
      @struct_cache[type] ||= create_llvm_struct_type(type)
    end

    def create_llvm_struct_type(type : InstanceVarContainer)
      LLVM.struct_type(type.llvm_name) do
        ivars = type.all_instance_vars
        element_types = Array(LibLLVM::TypeRef).new(ivars.length)
        ivars.each { |name, ivar| element_types.push llvm_embedded_type(ivar.type) }
        element_types
      end
    end

    def create_llvm_struct_type(type : CStructType)
      LLVM.struct_type(type.llvm_name) do
        vars = type.vars
        element_types = Array(LibLLVM::TypeRef).new(vars.length)
        vars.each { |name, var| element_types.push llvm_embedded_type(var.type) }
        element_types
      end
    end

    def create_llvm_struct_type(type : CUnionType)
      max_size = 0
      max_type :: LibLLVM::TypeRef
      type.vars.each do |name, var|
        llvm_type = llvm_embedded_type(var.type)
        size = size_of(llvm_type)
        if size > max_size
          max_size = size
          max_type = llvm_type
        end
      end

      LLVM.struct_type(type.llvm_name, [max_type] of LibLLVM::TypeRef)
    end

    def create_llvm_struct_type(type)
      raise "Bug: called llvm_struct_type for #{type}"
    end

    def llvm_arg_type(type)
      @arg_cache[type] ||= create_llvm_arg_type(type)
    end

    def create_llvm_arg_type(type)
      llvm_type type
    end

    def llvm_embedded_type(type)
      @embedded_cache[type] ||= create_llvm_embedded_type type
    end

    def create_llvm_embedded_type(type : CStructType)
      llvm_struct_type type
    end

    def create_llvm_embedded_type(type : CUnionType)
      llvm_struct_type type
    end

    def create_llvm_embedded_type(type : NoReturnType)
      LLVM::Int8
    end

    def create_llvm_embedded_type(type)
      llvm_type type
    end

    def size_of(type)
      @layout.size_in_bytes type
    end
  end
end
