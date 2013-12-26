require "../types"
require "../llvm"

module Crystal
  class LLVMTyper
    HIERARCHY_LLVM_TYPE = LLVM.struct_type("Object+", [LLVM::Int32, LLVM.pointer_type(LLVM::Int8)])
    HIERARCHY_LLVM_ARG_TYPE = LLVM.pointer_type(HIERARCHY_LLVM_TYPE)

    getter landing_pad_type

    def initialize(flags)
      @cache = {} of Type => LibLLVM::TypeRef
      @struct_cache = {} of Type => LibLLVM::TypeRef
      @arg_cache = {} of Type => LibLLVM::TypeRef
      @embedded_cache = {} of Type => LibLLVM::TypeRef
      @is_64bit = flags.includes?("x86_64")

      target = LLVM::Target.first
      machine = target.create_target_machine("i686-unknown-linux").not_nil!
      @layout = machine.data_layout.not_nil!
      @landing_pad_type = LLVM.struct_type("landing_pad", [LLVM.pointer_type(LLVM::Int8), LLVM::Int32])
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
      LLVM::Int32
    end

    def create_llvm_type(type : GenericClassInstanceMetaclass)
      LLVM::Int32
    end

    def create_llvm_type(type : HierarchyTypeMetaclass)
      LLVM::Int32
    end

    def create_llvm_type(type : PointerInstanceType)
      pointed_type = llvm_embedded_type type.var.type
      pointed_type = LLVM::Int8 if pointed_type == LLVM::Void
      LLVM.pointer_type(pointed_type)
    end

    def create_llvm_type(type : UnionType)
      LLVM.struct_type(type.llvm_name) do |struct|
        @cache[type] = struct

        max_size = 0
        type.union_types.each do |subtype|
          unless subtype.void?
            size = size_of(llvm_type(subtype))
            max_size = size if size > max_size
          end
        end
        max_size /= (@is_64bit ? 8 : 4)
        max_size = 1 if max_size == 0

        llvm_value_type = LLVM.array_type(@is_64bit ? LLVM::Int64 : LLVM::Int32, max_size)
        [LLVM::Int32, llvm_value_type] of LibLLVM::TypeRef
      end
    end

    def create_llvm_type(type : NilableType)
      llvm_type type.not_nil_type
    end

    def create_llvm_type(type : CStructType)
      llvm_struct_type(type)
    end

    def create_llvm_type(type : CUnionType)
      llvm_struct_type(type)
    end

    def create_llvm_type(type : TypeDefType)
      llvm_type type.typedef
    end

    def create_llvm_type(type : NoReturnType)
      LLVM::Void
    end

    def create_llvm_type(type : HierarchyType)
      HIERARCHY_LLVM_TYPE
    end

    def create_llvm_type(type : FunType)
      arg_types = type.arg_types.map { |arg_type| llvm_arg_type(arg_type) }
      LLVM.pointer_type(LLVM.function_type(arg_types, llvm_type(type.return_type)))
    end

    def create_llvm_type(type : AliasType)
      llvm_type(type.remove_alias)
    end

    def create_llvm_type(type)
      raise "Bug: called create_llvm_type for #{type}"
    end

    def llvm_struct_type(type)
      @struct_cache[type] ||= create_llvm_struct_type(type)
    end

    def create_llvm_struct_type(type : InstanceVarContainer)
      LLVM.struct_type(type.llvm_name) do |struct|
        @struct_cache[type] = struct

        ivars = type.all_instance_vars
        element_types = Array(LibLLVM::TypeRef).new(ivars.length)
        ivars.each { |name, ivar| element_types.push llvm_embedded_type(ivar.type) }
        element_types
      end
    end

    def create_llvm_struct_type(type : CStructType)
      LLVM.struct_type(type.llvm_name) do |struct|
        @struct_cache[type] = struct

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
        var_type = var.type
        unless var_type.void?
          llvm_type = llvm_embedded_type(var_type)
          size = size_of(llvm_type)
          if size > max_size
            max_size = size
            max_type = llvm_type
          end
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

    def create_llvm_arg_type(type : UnionType)
      LLVM.pointer_type llvm_type(type)
    end

    def create_llvm_arg_type(type : CStructType)
      LLVM.pointer_type llvm_type(type)
    end

    def create_llvm_arg_type(type : CUnionType)
      LLVM.pointer_type llvm_type(type)
    end

    def create_llvm_arg_type(type : NilableType)
      llvm_type(type)
    end

    def create_llvm_arg_type(type : HierarchyType)
      HIERARCHY_LLVM_ARG_TYPE
    end

    def create_llvm_arg_type(type : AliasType)
      llvm_arg_type(type.remove_alias)
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

    def create_llvm_embedded_type(type : VoidType)
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
