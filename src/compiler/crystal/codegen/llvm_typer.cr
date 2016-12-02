require "../types"
require "llvm"

module Crystal
  class LLVMTyper
    TYPE_ID_POINTER = LLVM::Int32.pointer
    PROC_TYPE       = LLVM::Type.struct [LLVM::VoidPointer, LLVM::VoidPointer], "->"
    NIL_TYPE        = LLVM::Type.struct([] of LLVM::Type, "Nil")
    NIL_VALUE       = NIL_TYPE.null

    getter landing_pad_type : LLVM::Type

    alias TypeCache = Hash(Type, LLVM::Type)

    @layout : LLVM::TargetData
    @landing_pad_type : LLVM::Type

    def initialize(@program : Program)
      @cache = TypeCache.new
      @struct_cache = TypeCache.new
      @union_value_cache = TypeCache.new

      # For union types we just need to know the maximum size of their types.
      # It might happen that we have a recursive type, for example:
      #
      # ```
      # struct Foo
      #   def initialize
      #     @x = uninitialized Pointer(Int32 | Foo)
      #   end
      # end
      # ```
      #
      # In that case, when we are computing the llvm type of Foo, we will
      # need to compute the llvm type of `@x`. Its type is a pointer to
      # a union. In order to compute the llvm type of a union we need
      # to compute the size of each type. For this, we compute the llvm
      # type of each type in the union and then get their size. The problem
      # here is that we are computing `Foo`, so we can't know its size yet.
      #
      # To solve this, when computing the llvm type of the union types,
      # we do it with a `wants_size` flag. In the case of pointers we
      # can just return a word size (using size_of(LLVM::VoidPointer)) instead
      # of computing the llvm type of the pointer element. This avoids the
      # recursion.
      #
      # We still need a separate cache for this types that we use to compute
      # types, because there can be cycles.
      @wants_size_cache = TypeCache.new
      @wants_size_struct_cache = TypeCache.new
      @wants_size_union_value_cache = TypeCache.new

      @types_being_computed = Set(Type).new

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

    def llvm_type(type, wants_size = false)
      type = type.remove_indirection

      if wants_size
        @wants_size_cache[type] ||= create_llvm_type(type, wants_size: true)
      else
        @cache[type] ||= create_llvm_type(type, wants_size)
      end
    end

    private def create_llvm_type(type : NoReturnType, wants_size)
      LLVM::Void
    end

    private def create_llvm_type(type : VoidType, wants_size)
      LLVM::Void
    end

    private def create_llvm_type(type : NilType, wants_size)
      NIL_TYPE
    end

    private def create_llvm_type(type : BoolType, wants_size)
      LLVM::Int1
    end

    private def create_llvm_type(type : CharType, wants_size)
      LLVM::Int32
    end

    private def create_llvm_type(type : IntegerType, wants_size)
      LLVM::Type.int(8 * type.bytes)
    end

    private def create_llvm_type(type : FloatType, wants_size)
      type.bytes == 4 ? LLVM::Float : LLVM::Double
    end

    private def create_llvm_type(type : SymbolType, wants_size)
      LLVM::Int32
    end

    private def create_llvm_type(type : EnumType, wants_size)
      llvm_type(type.base_type)
    end

    private def create_llvm_type(type : ProcInstanceType, wants_size)
      PROC_TYPE
    end

    private def create_llvm_type(type : InstanceVarContainer, wants_size)
      final_type = llvm_struct_type(type, wants_size)
      unless type.struct?
        final_type = final_type.pointer
      end
      final_type
    end

    private def create_llvm_type(type : MetaclassType, wants_size)
      LLVM::Int32
    end

    private def create_llvm_type(type : LibType, wants_size)
      LLVM::Int32
    end

    private def create_llvm_type(type : GenericClassInstanceMetaclassType, wants_size)
      LLVM::Int32
    end

    private def create_llvm_type(type : GenericModuleInstanceMetaclassType, wants_size)
      LLVM::Int32
    end

    private def create_llvm_type(type : VirtualMetaclassType, wants_size)
      LLVM::Int32
    end

    private def create_llvm_type(type : PointerInstanceType, wants_size)
      if wants_size
        return LLVM::VoidPointer
      end

      pointed_type = llvm_embedded_type(type.element_type, wants_size)
      pointed_type = LLVM::Int8 if pointed_type == LLVM::Void
      pointed_type.pointer
    end

    private def create_llvm_type(type : StaticArrayInstanceType, wants_size)
      pointed_type = llvm_embedded_type(type.element_type, wants_size)
      pointed_type = LLVM::Int8 if pointed_type == LLVM::Void
      pointed_type.array type.size.as(NumberLiteral).value.to_i
    end

    private def create_llvm_type(type : TupleInstanceType, wants_size)
      LLVM::Type.struct(type.llvm_name) do |a_struct|
        if wants_size
          @wants_size_cache[type] = a_struct
        else
          @cache[type] = a_struct
        end

        type.tuple_types.map { |tuple_type| llvm_embedded_type(tuple_type, wants_size).as(LLVM::Type) }
      end
    end

    private def create_llvm_type(type : NamedTupleInstanceType, wants_size)
      LLVM::Type.struct(type.llvm_name) do |a_struct|
        if wants_size
          @wants_size_cache[type] = a_struct
        else
          @cache[type] = a_struct
        end

        type.entries.map { |entry| llvm_embedded_type(entry.type, wants_size).as(LLVM::Type) }
      end
    end

    private def create_llvm_type(type : NilableType, wants_size)
      llvm_type(type.not_nil_type, wants_size)
    end

    private def create_llvm_type(type : ReferenceUnionType, wants_size)
      TYPE_ID_POINTER
    end

    private def create_llvm_type(type : NilableReferenceUnionType, wants_size)
      TYPE_ID_POINTER
    end

    private def create_llvm_type(type : NilableProcType, wants_size)
      PROC_TYPE
    end

    private def create_llvm_type(type : NilablePointerType, wants_size)
      llvm_type(type.pointer_type, wants_size)
    end

    private def create_llvm_type(type : MixedUnionType, wants_size)
      LLVM::Type.struct(type.llvm_name) do |a_struct|
        if wants_size
          @wants_size_cache[type] = a_struct
        else
          @cache[type] = a_struct
        end

        max_size = 0
        type.expand_union_types.each do |subtype|
          unless subtype.void?
            size = size_of(llvm_type(subtype, wants_size: true))
            max_size = size if size > max_size
          end
        end

        max_size /= pointer_size.to_f
        max_size = max_size.ceil.to_i

        max_size = 1 if max_size == 0

        llvm_value_type = LLVM::SizeT.array(max_size)

        if wants_size
          @wants_size_union_value_cache[type] = llvm_value_type
        else
          @union_value_cache[type] = llvm_value_type
        end

        [LLVM::Int32, llvm_value_type]
      end
    end

    private def create_llvm_type(type : TypeDefType, wants_size)
      llvm_type(type.typedef, wants_size)
    end

    private def create_llvm_type(type : VirtualType, wants_size)
      TYPE_ID_POINTER
    end

    private def create_llvm_type(type : AliasType, wants_size)
      llvm_type(type.remove_alias, wants_size)
    end

    private def create_llvm_type(type : NonGenericModuleType | GenericClassType, wants_size)
      # This can only be reached if the module or generic class don't have implementors
      LLVM::Int1
    end

    private def create_llvm_type(type : Type, wants_size)
      raise "Bug: called create_llvm_type for #{type}"
    end

    def llvm_struct_type(type, wants_size = false)
      type = type.remove_indirection

      if wants_size
        @wants_size_struct_cache[type] ||= create_llvm_struct_type(type, wants_size: true)
      else
        @struct_cache[type] ||= create_llvm_struct_type(type, wants_size)
      end
    end

    private def create_llvm_struct_type(type : StaticArrayInstanceType, wants_size)
      llvm_type(type, wants_size)
    end

    private def create_llvm_struct_type(type : TupleInstanceType, wants_size)
      llvm_type(type, wants_size)
    end

    private def create_llvm_struct_type(type : NamedTupleInstanceType, wants_size)
      llvm_type(type, wants_size)
    end

    private def create_llvm_struct_type(type : InstanceVarContainer, wants_size)
      if type.extern_union?
        return create_llvm_c_union_struct_type(type, wants_size)
      end

      LLVM::Type.struct(type.llvm_name, type.packed?) do |a_struct|
        if wants_size
          @wants_size_struct_cache[type] = a_struct
        else
          @struct_cache[type] = a_struct
        end

        ivars = type.all_instance_vars
        ivars_size = ivars.size
        ivars_size += 1 unless type.struct?

        element_types = Array(LLVM::Type).new(ivars_size)
        element_types.push LLVM::Int32 unless type.struct? # For the type id

        @types_being_computed.add(type)
        ivars.each do |name, ivar|
          if type.extern?
            element_types.push llvm_embedded_c_type(ivar.type, wants_size)
          else
            element_types.push llvm_embedded_type(ivar.type, wants_size)
          end
        end
        @types_being_computed.delete(type)

        element_types
      end
    end

    private def create_llvm_c_union_struct_type(type, wants_size)
      LLVM::Type.struct(type.llvm_name) do |a_struct|
        if wants_size
          @wants_size_struct_cache[type] = a_struct
        else
          @struct_cache[type] = a_struct
        end

        max_size = 0
        max_align = 0
        max_align_type = nil
        max_align_type_size = 0

        type.instance_vars.each do |name, var|
          var_type = var.type
          unless var_type.void?
            llvm_type = llvm_embedded_c_type(var_type, wants_size: true)
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

    private def create_llvm_struct_type(type : Type, wants_size)
      raise "Bug: called llvm_struct_type for #{type}"
    end

    def llvm_embedded_type(type, wants_size = false)
      type = type.remove_indirection
      case type
      when NoReturnType, VoidType
        LLVM::Int8
      else
        llvm_type(type, wants_size)
      end
    end

    def llvm_embedded_c_type(type : ProcInstanceType, wants_size = false)
      proc_type(type)
    end

    def llvm_embedded_c_type(type, wants_size = false)
      llvm_embedded_type(type, wants_size)
    end

    def llvm_c_type(type : ProcInstanceType)
      proc_type(type)
    end

    def llvm_c_type(type : NilableProcType)
      proc_type(type.proc_type)
    end

    def llvm_c_type(type : TupleInstanceType)
      llvm_struct_type(type)
    end

    def llvm_c_type(type)
      if type.extern?
        llvm_struct_type(type)
      elsif type.passed_by_value?
        # C types that are passed by value must be considered,
        # for the ABI, as being passed behind a pointer
        llvm_type(type).pointer
      else
        llvm_type(type)
      end
    end

    def llvm_c_return_type(type : NilType)
      LLVM::Void
    end

    def llvm_c_return_type(type)
      llvm_c_type(type)
    end

    def llvm_return_type(type : NilType)
      LLVM::Void
    end

    def llvm_return_type(type)
      llvm_type(type)
    end

    def closure_type(type : ProcInstanceType)
      arg_types = type.arg_types.map { |arg_type| llvm_type(arg_type) }
      arg_types.insert(0, LLVM::VoidPointer)
      LLVM::Type.function(arg_types, llvm_type(type.return_type)).pointer
    end

    def proc_type(type : ProcInstanceType)
      arg_types = type.arg_types.map { |arg_type| llvm_type(arg_type).as(LLVM::Type) }
      LLVM::Type.function(arg_types, llvm_type(type.return_type)).pointer
    end

    def closure_context_type(vars, parent_llvm_type, self_type)
      LLVM::Type.struct("closure") do |a_struct|
        elems = vars.map { |var| llvm_type(var.type).as(LLVM::Type) }
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
