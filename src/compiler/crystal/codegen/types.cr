module Crystal
  class Type
    # Returns `true` if this type is passed as a `self` argument
    # in the codegen phase. For example a method whose receiver is
    # the Program, or a Metaclass, doesn't have a `self` argument.
    def passed_as_self?
      case self
      when Program, FileModule, LibType, MetaclassType
        false
      else
        true
      end
    end

    # Returns `true` if this type passed by value (if it's not a primitive type).
    # In the codegen phase these types are passed as byval pointers.
    def passed_by_value?
      case self
      when PrimitiveType, PointerInstanceType, ProcInstanceType
        false
      when TupleInstanceType, NamedTupleInstanceType, MixedUnionType
        true
      when VirtualType
        self.struct?
      when NonGenericModuleType
        self.including_types.try &.passed_by_value?
      when GenericModuleInstanceType
        self.including_types.try &.passed_by_value?
      when GenericClassInstanceType
        self.generic_type.passed_by_value?
      when TypeDefType
        self.typedef.passed_by_value?
      when AliasType
        self.aliased_type.passed_by_value?
      when ClassType
        self.struct?
      else
        false
      end
    end

    # Returns `true` if the type has inner pointers.
    # This is useful to know because if a type doesn't have
    # inner pointers we can use `malloc_atomic` instead of
    # `malloc` in `Pointer.malloc` for a tiny performance boost.
    def has_inner_pointers?
      case self
      when .void?
        # We consider Void to have pointers, so doing
        # Pointer(Void).malloc(...).as(ReferenceType)
        # will consider potential inner pointers as such.
        true
      when PointerInstanceType
        true
      when ProcInstanceType
        # A proc can have closure data which might have pointers
        true
      when StaticArrayInstanceType
        self.element_type.has_inner_pointers?
      when TupleInstanceType
        self.tuple_types.any? &.has_inner_pointers?
      when NamedTupleInstanceType
        self.entries.any? &.type.has_inner_pointers?
      when PrimitiveType
        false
      when EnumType
        false
      when UnionType
        self.union_types.any? &.has_inner_pointers?
      when AliasType
        self.aliased_type.has_inner_pointers?
      when TypeDefType
        self.typedef.has_inner_pointers?
      when VirtualType
        if struct?
          self.subtypes.any? &.has_inner_pointers?
        else
          true
        end
      when InstanceVarContainer
        if struct?
          all_instance_vars.each_value.any? &.type.has_inner_pointers?
        else
          true
        end
      else
        true
      end
    end

    def llvm_name
      String.build do |io|
        llvm_name io
      end
    end

    def llvm_name(io)
      to_s_with_options io, codegen: true
    end

    def append_to_expand_union_types(types)
      types << self
    end
  end

  class PrimitiveType
    def llvm_name(io)
      io << name
    end
  end

  class AliasType
    def llvm_name(io)
      io << "alias."
      to_s_with_options io, codegen: true
    end
  end

  class NonGenericClassType
    def llvm_name(io)
      if extern?
        io << (extern_union? ? "union" : "struct")
        io << "."
      end
      to_s_with_options io, codegen: true
    end
  end

  class NonGenericModuleType
    def append_to_expand_union_types(types)
      if including_types = @including_types
        including_types.each &.virtual_type.append_to_expand_union_types(types)
      else
        types << self
      end
    end
  end

  class GenericModuleInstanceType
    def append_to_expand_union_types(types)
      if including_types = @including_types
        including_types.each &.virtual_type.append_to_expand_union_types(types)
      else
        types << self
      end
    end
  end

  class UnionType
    def expand_union_types
      if union_types.any?(&.is_a?(NonGenericModuleType))
        types = [] of Type
        union_types.each &.append_to_expand_union_types(types)
        types
      else
        union_types
      end
    end
  end

  class TypeDefType
    def llvm_name(io)
      typedef.llvm_name(io)
    end
  end

  class Const
    property initializer : LLVM::Value?

    def initialized_llvm_name
      "#{llvm_name}:init"
    end

    # Returns `true` if this constant's value is a simple literal, like
    # `nil`, a number, char, string or symbol literal.
    def simple?
      value.simple_literal?
    end

    @compile_time_value : (Int16 | Int32 | Int64 | Int8 | UInt16 | UInt32 | UInt64 | UInt8 | Bool | Char | Nil)
    @computed_compile_time_value = false

    # Returns a value if this constant's value can be evaluated at
    # compile time (things like `1 + 2` and such). Returns nil otherwise.
    def compile_time_value
      unless @computed_compile_time_value
        @computed_compile_time_value = true

        case value = self.value
        when BoolLiteral
          @compile_time_value = value.value
        when CharLiteral
          @compile_time_value = value.value
        else
          case type = value.type?
          when IntegerType, EnumType
            interpreter = MathInterpreter.new(namespace, visitor)
            @compile_time_value = interpreter.interpret(value) rescue nil
          end
        end
      end

      @compile_time_value
    end
  end
end
