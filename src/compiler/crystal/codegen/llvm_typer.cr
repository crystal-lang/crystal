require "../types"
require "llvm"

module Crystal
  class LLVMTyper
    TYPE_ID_POINTER = LLVM::Int32.pointer
    FUN_TYPE = LLVM::Type.struct [LLVM::VoidPointer, LLVM::VoidPointer], "->"

    getter landing_pad_type

    alias TypeCache = Hash(Type, LLVM::Type)

    def initialize(program)
      @cache = TypeCache.new
      @struct_cache = TypeCache.new
      @union_value_cache = TypeCache.new

      machine = program.target_machine
      @layout = machine.data_layout.not_nil!
      @landing_pad_type = LLVM::Type.struct([LLVM::VoidPointer, LLVM::Int32], "landing_pad")
    end

    def llvm_string_type(bytesize)
      LLVM::Type.struct [
        LLVM::Int32,                              # type_id
        LLVM::Int32,                              # @bytesize
        LLVM::Int32,                              # @length
        LLVM::Int8.array(bytesize + 1) # @c
      ]
    end

    def llvm_type(type)
      @cache[type] ||= create_llvm_type(type)
    end

    def create_llvm_type(type : NoReturnType)
      LLVM::Void
    end

    def create_llvm_type(type : VoidType)
      LLVM::Void
    end

    def create_llvm_type(type : NilType)
      LLVM::Int1
    end

    def create_llvm_type(type : BoolType)
      LLVM::Int1
    end

    def create_llvm_type(type : CharType)
      LLVM::Int32
    end

    def create_llvm_type(type : IntegerType)
      LLVM::Type.int(8 * type.bytes)
    end

    def create_llvm_type(type : FloatType)
      type.bytes == 4 ? LLVM::Float : LLVM::Double
    end

    def create_llvm_type(type : SymbolType)
      LLVM::Int32
    end

    def create_llvm_type(type : CEnumType)
      llvm_type(type.base_type)
    end

    def create_llvm_type(type : FunInstanceType)
      FUN_TYPE
    end

    def create_llvm_type(type : InstanceVarContainer)
      final_type = llvm_struct_type(type)
      unless type.struct?
        final_type = final_type.pointer
      end
      final_type
    end

    def create_llvm_type(type : MetaclassType)
      LLVM::Int32
    end

    def create_llvm_type(type : GenericClassInstanceMetaclassType)
      LLVM::Int32
    end

    def create_llvm_type(type : VirtualMetaclassType)
      LLVM::Int32
    end

    def create_llvm_type(type : PointerInstanceType)
      pointed_type = llvm_embedded_type type.element_type
      pointed_type = LLVM::Int8 if pointed_type == LLVM::Void
      pointed_type.pointer
    end

    def create_llvm_type(type : StaticArrayInstanceType)
      pointed_type = llvm_embedded_type type.element_type
      pointed_type = LLVM::Int8 if pointed_type == LLVM::Void
      pointed_type.array (type.size as NumberLiteral).value.to_i
    end

    def create_llvm_type(type : TupleInstanceType)
      LLVM::Type.struct(type.llvm_name) do |a_struct|
        @cache[type] = a_struct

        element_types = Array(LLVM::Type).new(type.tuple_types.length)
        type.tuple_types.each do |tuple_type|
          element_types << llvm_embedded_type(tuple_type)
        end
        element_types
      end
    end

    def create_llvm_type(type : NilableType)
      llvm_type type.not_nil_type
    end

    def create_llvm_type(type : ReferenceUnionType)
      TYPE_ID_POINTER
    end

    def create_llvm_type(type : NilableReferenceUnionType)
      TYPE_ID_POINTER
    end

    def create_llvm_type(type : NilableFunType)
      FUN_TYPE
    end

    def create_llvm_type(type : NilablePointerType)
      llvm_type(type.pointer_type)
    end

    def create_llvm_type(type : MixedUnionType)
      LLVM::Type.struct(type.llvm_name) do |a_struct|
        @cache[type] = a_struct

        max_size = 0
        type.union_types.each do |subtype|
          unless subtype.void?
            size = size_of(llvm_type(subtype))
            max_size = size if size > max_size
          end
        end

        ifdef x86_64
          max_size /= 8.0
        else
          max_size /= 4.0
        end
        max_size = max_size.ceil

        max_size = 1 if max_size == 0

        llvm_value_type = LLVM::SizeT.array(max_size)
        @union_value_cache[type] = llvm_value_type

        [LLVM::Int32, llvm_value_type]
      end
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

    def create_llvm_type(type : VirtualType)
      TYPE_ID_POINTER
    end

    def create_llvm_type(type : AliasType)
      llvm_type(type.remove_alias)
    end

    def create_llvm_type(type : NonGenericModuleType)
      if including_type = type.including_types
        llvm_type(including_type)
      else
        LLVM::Int1
      end
    end

    def create_llvm_type(type : Type)
      raise "Bug: called create_llvm_type for #{type}"
    end

    def llvm_struct_type(type)
      @struct_cache[type] ||= create_llvm_struct_type(type)
    end

    def create_llvm_struct_type(type : StaticArrayInstanceType)
      llvm_type type
    end

    def create_llvm_struct_type(type : InstanceVarContainer)
      LLVM::Type.struct(type.llvm_name) do |a_struct|
        @struct_cache[type] = a_struct

        ivars = type.all_instance_vars
        ivars_length = ivars.length

        unless type.struct?
          ivars_length += 1
        end

        element_types = Array(LLVM::Type).new(ivars_length)

        unless type.struct?
          element_types.push LLVM::Int32 # For the type id
        end

        ivars.each do |name, ivar|
          if ivar_type = ivar.type?
            element_types.push llvm_embedded_type(ivar_type)
          else
            # This is for untyped fields: we don't really care how to represent them in memory.
            element_types.push LLVM::Int8
          end
        end
        element_types
      end
    end

    def create_llvm_struct_type(type : CStructType)
      LLVM::Type.struct(type.llvm_name, type.packed) do |a_struct|
        @struct_cache[type] = a_struct

        vars = type.vars
        element_types = Array(LLVM::Type).new(vars.length)
        vars.each { |name, var| element_types.push llvm_embedded_c_type(var.type) }
        element_types
      end
    end

    def create_llvm_struct_type(type : CUnionType)
      max_size = 0
      max_type = nil
      type.vars.each do |name, var|
        var_type = var.type
        unless var_type.void?
          llvm_type = llvm_embedded_c_type(var_type)
          size = size_of(llvm_type)
          if size > max_size
            max_size = size
            max_type = llvm_type
          end
        end
      end

      LLVM::Type.struct([max_type.not_nil!] of LLVM::Type, type.llvm_name)
    end

    def create_llvm_struct_type(type : Type)
      raise "Bug: called llvm_struct_type for #{type}"
    end

    def llvm_arg_type(type : AliasType)
      llvm_arg_type(type.remove_alias)
    end

    def llvm_arg_type(type : Type)
      if type.passed_by_value?
        llvm_type(type).pointer
      else
        llvm_type(type)
      end
    end

    def llvm_embedded_type(type : CStructType)
      llvm_struct_type type
    end

    def llvm_embedded_type(type : CUnionType)
      llvm_struct_type type
    end

    def llvm_embedded_type(type : FunInstanceType)
      llvm_type type
    end

    def llvm_embedded_type(type : InstanceVarContainer)
      if type.struct?
        llvm_struct_type type
      else
        llvm_type type
      end
    end

    def llvm_embedded_type(type : StaticArrayInstanceType)
      llvm_type type
    end

    def llvm_embedded_type(type : NoReturnType)
      LLVM::Int8
    end

    def llvm_embedded_type(type : VoidType)
      LLVM::Int8
    end

    def llvm_embedded_type(type)
      llvm_type type
    end

    def llvm_embedded_c_type(type : FunInstanceType)
      fun_type(type)
    end

    def llvm_embedded_c_type(type)
      llvm_embedded_type type
    end

    def llvm_c_type(type : FunInstanceType)
      fun_type(type)
    end

    def llvm_c_type(type : NilableFunType)
      fun_type(type.fun_type)
    end

    def llvm_c_type(type)
      llvm_arg_type(type)
    end

    def closure_type(type : FunInstanceType)
      arg_types = type.arg_types.map { |arg_type| llvm_arg_type(arg_type) }
      arg_types.insert(0, LLVM::VoidPointer)
      LLVM::Type.function(arg_types, llvm_type(type.return_type)).pointer
    end

    def fun_type(type : FunInstanceType)
      arg_types = Array(LLVM::Type).new(type.arg_types.length)
      type.arg_types.each do |arg_type|
        arg_types << llvm_arg_type(arg_type)
      end
      LLVM::Type.function(arg_types, llvm_type(type.return_type)).pointer
    end

    def closure_context_type(vars, parent_llvm_type, self_type)
      LLVM::Type.struct("closure") do |a_struct|
        elems = Array(LLVM::Type).new(vars.length + (parent_llvm_type ? 1 : 0))
        vars.each do |var|
          elems << llvm_type(var.type)
        end
        if parent_llvm_type
          elems << parent_llvm_type.pointer
        end
        if self_type
          elems << llvm_type(self_type)
        end
        elems
      end
    end

    def size_of(type)
      @layout.size_in_bytes type
    end

    def union_value_type(type : MixedUnionType)
      @union_value_cache[type]
    end
  end
end
