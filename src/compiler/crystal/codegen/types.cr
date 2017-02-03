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

    def simple?
      value.simple_literal?
    end
  end
end
