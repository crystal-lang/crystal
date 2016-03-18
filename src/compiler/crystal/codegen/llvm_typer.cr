require "../types"
require "llvm"

module Crystal
  class LLVMTyper
    TYPE_ID_POINTER = LLVM::Int32.pointer
    FUN_TYPE        = LLVM::Type.struct [LLVM::VoidPointer, LLVM::VoidPointer], "->"
    NIL_TYPE        = LLVM::Type.struct([] of LLVM::Type, "Nil")
    NIL_VALUE       = NIL_TYPE.null

    getter landing_pad_type : LLVM::Type

    alias TypeCache = Hash(Type, LLVM::Type)

    @cache : Hash(Type, LLVM::Type)
    @struct_cache : Hash(Type, LLVM::Type)
    @union_value_cache : Hash(Type, LLVM::Type)
    @layout : LLVM::TargetData
    @landing_pad_type : LLVM::Type

    def initialize(program)
      @cache = TypeCache.new
      @struct_cache = TypeCache.new
      @union_value_cache = TypeCache.new

      machine = program.target_machine
      @layout = machine.data_layout
      @landing_pad_type = LLVM::Type.struct([LLVM::VoidPointer, LLVM::Int32], "landing_pad")
    end

    def llvm_string_type(bytesize)
      LLVM::Type.struct [
        LLVM::Int32,                    # type_id
        LLVM::Int32,                    # @bytesize
        LLVM::Int32,                    # @length
        LLVM::Int8.array(bytesize + 1), # @c
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
      NIL_TYPE
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

    def create_llvm_type(type : EnumType)
      llvm_type(type.base_type)
    end

    def create_llvm_type(type : FunInstanceType)
      FUN_TYPE
    end

    def create_llvm_type(type : CStructType)
      llvm_struct_type(type)
    end

    def create_llvm_type(type : CUnionType)
      llvm_struct_type(type)
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

    def create_llvm_type(type : LibType)
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

        type.tuple_types.map { |tuple_type| llvm_embedded_type(tuple_type) }
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
        type.expand_union_types.each do |subtype|
          unless subtype.void?
            size = size_of(llvm_type(subtype))
            max_size = size if size > max_size
          end
        end

        max_size /= pointer_size.to_f
        max_size = max_size.ceil.to_i

        max_size = 1 if max_size == 0

        llvm_value_type = LLVM::SizeT.array(max_size)
        @union_value_cache[type] = llvm_value_type

        [LLVM::Int32, llvm_value_type]
      end
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

    def create_llvm_type(type : NonGenericModuleType | GenericClassType)
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

    def create_llvm_struct_type(type : TupleInstanceType)
      llvm_type type
    end

    def create_llvm_struct_type(type : CStructType)
      LLVM::Type.struct(type.llvm_name, type.packed) do |a_struct|
        @struct_cache[type] = a_struct
        type.vars.map { |name, var| llvm_embedded_c_type(var.type) as LLVM::Type }
      end
    end

    def create_llvm_struct_type(type : CUnionType)
      LLVM::Type.struct(type.llvm_name) do |a_struct|
        @struct_cache[type] = a_struct

        max_size = 0
        max_align = 0
        max_align_type = nil
        max_align_type_size = 0

        type.vars.each do |name, var|
          var_type = var.type
          unless var_type.void?
            llvm_type = llvm_embedded_c_type(var_type)
            size = size_of(llvm_type)
            align = align_of(llvm_type)

            if size > max_size
              max_size = size
            end

            if align > max_align
              max_align = align
              max_align_type = llvm_type
              max_align_type_size = size
            end
          end
        end

        max_align_type = max_align_type.not_nil!
        union_fill = [max_align_type] of LLVM::Type
        if max_align_type_size < max_size
          union_fill << LLVM::Int8.array(max_size - max_align_type_size)
        end

        union_fill
      end
    end

    def create_llvm_struct_type(type : InstanceVarContainer)
      LLVM::Type.struct(type.llvm_name) do |a_struct|
        @struct_cache[type] = a_struct

        ivars = type.all_instance_vars
        ivars_size = ivars.size

        unless type.struct?
          ivars_size += 1
        end

        element_types = Array(LLVM::Type).new(ivars_size)

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

    def llvm_embedded_type(type : PointerInstanceType)
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

    def llvm_c_type(type : CStructOrUnionType)
      llvm_struct_type(type)
    end

    def llvm_c_type(type : TupleInstanceType)
      llvm_struct_type(type)
    end

    def llvm_c_type(type)
      llvm_arg_type(type)
    end

    def llvm_c_return_type(type : CStructType)
      llvm_type(type)
    end

    def llvm_c_return_type(type)
      llvm_c_type(type)
    end

    def closure_type(type : FunInstanceType)
      arg_types = type.arg_types.map { |arg_type| llvm_arg_type(arg_type) }
      arg_types.insert(0, LLVM::VoidPointer)
      LLVM::Type.function(arg_types, llvm_type(type.return_type)).pointer
    end

    def fun_type(type : FunInstanceType)
      arg_types = type.arg_types.map { |arg_type| llvm_arg_type(arg_type) as LLVM::Type }
      LLVM::Type.function(arg_types, llvm_type(type.return_type)).pointer
    end

    def closure_context_type(vars, parent_llvm_type, self_type)
      LLVM::Type.struct("closure") do |a_struct|
        elems = vars.map { |var| llvm_type(var.type) as LLVM::Type }
        elems << parent_llvm_type.pointer if parent_llvm_type
        elems << llvm_type(self_type) if self_type
        elems
      end
    end

    def size_of(type)
      if type.void?
        0_u64
      else
        @layout.size_in_bytes type
      end
    end

    def align_of(type)
      @layout.abi_alignment(type)
    end

    @pointer_size : UInt64?

    def pointer_size
      @pointer_size ||= size_of(LLVM::VoidPointer)
    end

    def union_value_type(type : MixedUnionType)
      @union_value_cache[type]
    end
  end
end
