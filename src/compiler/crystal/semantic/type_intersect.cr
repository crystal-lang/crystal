require "../program"

module Crystal
  class Type
    # Given two types T and U, returns a common descendent V such that V <= T
    # and V <= U. This is the same as:
    #
    # ```
    # typeof(begin
    #   x = uninitialized T
    #   x.is_a?(U) ? x : raise ""
    # end)
    # ```
    #
    # except that `nil` is returned if the above produces `NoReturn`.
    def self.common_descendent(type1 : Type, type2 : Type)
      common_descendent_base(type1, type2)
    end

    def self.common_descendent(type1 : TupleInstanceType, type2 : TupleInstanceType)
      type1.implements?(type2) ? type1 : nil
    end

    def self.common_descendent(type1 : NamedTupleInstanceType, type2 : NamedTupleInstanceType)
      type1.implements?(type2) ? type1 : nil
    end

    def self.common_descendent(type1 : ProcInstanceType, type2 : ProcInstanceType)
      type1.compatible_with?(type2) ? type2 : nil
    end

    def self.common_descendent(type1 : NonGenericModuleType | GenericModuleInstanceType, type2 : AliasType)
      common_descendent(type1, type2.remove_alias) ||
        common_descendent_including_types(type1, type2)
    end

    def self.common_descendent(type1 : NonGenericModuleType | GenericModuleInstanceType, type2 : UnionType)
      common_descendent_union(type1, type2) ||
        common_descendent_including_types(type1, type2)
    end

    def self.common_descendent(type1 : NonGenericModuleType | GenericModuleInstanceType, type2 : VirtualType)
      common_descendent_including_types(type1, type2)
    end

    def self.common_descendent(type1 : NonGenericModuleType | GenericModuleInstanceType, type2 : GenericClassType)
      common_descendent_instance_and_generic(type1, type2) ||
        common_descendent_including_types(type1, type2)
    end

    def self.common_descendent(type1 : GenericModuleInstanceType, type2 : GenericModuleInstanceType)
      common_descendent_generic_instances(type1, type2) ||
        common_descendent_base(type1, type2) ||
        common_descendent_including_types(type1, type2)
    end

    def self.common_descendent(type1 : GenericModuleInstanceType, type2 : GenericModuleType)
      return type1 if type1.generic_type == type2

      common_descendent_instance_and_generic(type1, type2) ||
        common_descendent_including_types(type1, type2)
    end

    def self.common_descendent(type1 : NonGenericModuleType | GenericModuleInstanceType, type2 : Type)
      common_descendent_base(type1, type2) ||
        common_descendent_including_types(type1, type2)
    end

    def self.common_descendent(type1 : GenericClassInstanceType, type2 : GenericClassType)
      return type1 if type1.generic_type == type2

      common_descendent_instance_and_generic(type1, type2)
    end

    def self.common_descendent(type1 : GenericClassType, type2 : GenericClassInstanceType)
      common_descendent(type2, type1)
    end

    def self.common_descendent(type1 : GenericInstanceType, type2 : GenericInstanceType)
      common_descendent_generic_instances(type1, type2) ||
        common_descendent_base(type1, type2)
    end

    def self.common_descendent(type1 : MetaclassType, type2 : VirtualMetaclassType)
      # A module class can't be restricted into a class
      return nil if type1.instance_type.module?

      # `T+.class` is always a subtype of `Class`
      return type2 if type1 == type1.program.class_type

      restricted = common_descendent(type1.instance_type, type2.instance_type.base_type)
      restricted.try(&.metaclass)
    end

    def self.common_descendent(type1 : VirtualMetaclassType, type2 : MetaclassType)
      common_descendent(type2, type1)
    end

    def self.common_descendent(type1 : VirtualMetaclassType, type2 : VirtualMetaclassType)
      restricted = common_descendent(type1.instance_type, type2.instance_type)
      restricted.try(&.metaclass)
    end

    def self.common_descendent(type1 : GenericClassInstanceMetaclassType | GenericModuleInstanceMetaclassType, type2 : MetaclassType | VirtualMetaclassType)
      return type1 if type1.instance_type.generic_type.metaclass == type2

      # Special case: a GenericInstanceMetaclass with a union type is
      # the metaclass of a union type, for example Union(String | Int32).class.
      # In that case the intersection of that type with a non-union metaclass
      # will never match: it must also be another union type.
      return nil if type1.instance_type.is_a?(UnionType)

      restricted = common_descendent(type1.instance_type, type2.instance_type)
      restricted ? type1 : nil
    end

    def self.common_descendent(type1 : MetaclassType | VirtualMetaclassType, type2 : GenericClassInstanceMetaclassType | GenericModuleInstanceMetaclassType)
      common_descendent(type2, type1)
    end

    def self.common_descendent(type1 : UnionType, type2 : Type)
      types = type1.union_types.compact_map do |union_type|
        common_descendent(union_type, type2)
      end
      type1.program.type_merge_union_of(types)
    end

    def self.common_descendent(type1 : AliasType, type2 : AliasType)
      return type1 if type1 == type2

      if !type1.simple? && !type2.simple?
        return nil
      end

      common_descendent(type1.remove_alias, type2)
    end

    def self.common_descendent(type1 : AliasType, type2 : Type)
      common_descendent(type1.remove_alias, type2)
    end

    def self.common_descendent(type1 : TypeDefType, type2 : UnionType)
      common_descendent_union(type1, type2)
    end

    def self.common_descendent(type1 : TypeDefType, type2 : AliasType)
      type2 = type2.remove_alias
      return type1 if type1 == type2
      common_descendent(type1, type2)
    end

    def self.common_descendent(type1 : TypeDefType, type2 : Type)
      return type1 if type1 == type2

      restricted = common_descendent(type1.typedef, type2)
      if restricted == type1.typedef
        type1
      elsif restricted.is_a?(UnionType)
        type1.program.type_merge(restricted.union_types.map { |t| t == type1.typedef ? type1 : t })
      else
        restricted
      end
    end

    def self.common_descendent(type1 : VirtualType, type2 : VirtualType)
      return type1 if type1 == type2

      base_type1 = type1.base_type
      base_type2 = type2.base_type
      (common_descendent(base_type1, base_type2) || common_descendent(base_type2, base_type1)).try &.virtual_type
    end

    def self.common_descendent(type1 : VirtualType, type2 : AliasType)
      common_descendent(type1, type2.remove_alias)
    end

    def self.common_descendent(type1 : VirtualType, type2 : UnionType)
      types = type2.union_types.compact_map do |t|
        common_descendent(type1, t)
      end
      type1.program.type_merge_union_of types
    end

    def self.common_descendent(type1 : VirtualType, type2 : Type)
      base_type = type1.base_type

      if type2.implements?(base_type)
        type2.virtual_type
      elsif base_type.implements?(type2)
        type1
      elsif type2.module?
        types = base_type.subclasses.compact_map do |subclass|
          common_descendent(subclass.virtual_type, type2)
        end
        type1.program.type_merge_union_of types
      elsif base_type.is_a?(GenericInstanceType) && type2.is_a?(GenericType)
        # Consider the case of Foo(Int32) vs. Bar(T), with Bar(T) < Foo(T):
        # we want to return Bar(Int32), so we search in Bar's generic instantiations
        types = type2.instantiated_types.compact_map do |instance|
          next if instance.unbound? || instance.abstract?
          instance.virtual_type if instance.implements?(base_type)
        end
        type1.program.type_merge_union_of types
      else
        nil
      end
    end

    def self.common_descendent(type1 : NilType, type2 : VoidType)
      # Allow Nil to match Void (useful for `Pointer(Void)#value=`)
      type1
    end

    def self.common_descendent(type1 : GenericClassType, type2 : GenericClassType)
      return type1 if type1 == type2

      common_descendent_instance_and_generic(type1, type2)
    end

    def self.common_descendent(type1 : Type, type2 : AliasType)
      return type1 if type1 == type2

      common_descendent(type1, type2.remove_alias)
    end

    def self.common_descendent(type1 : Type, type2 : UnionType)
      common_descendent_union(type1, type2)
    end

    def self.common_descendent(type1 : Type, type2 : VirtualType)
      type1.implements?(type2.base_type) ? type1 : nil
    end

    def self.common_descendent(type1 : Type, type2 : GenericClassType)
      common_descendent_instance_and_generic(type1, type2)
    end

    private def self.common_descendent_base(type1, type2)
      if type1 == type2
        return type1
      end

      if type1.parents.try &.any? &.implements?(type2)
        return type1
      end
    end

    private def self.common_descendent_union(type, union)
      restricted = nil

      union.union_types.each do |union_type|
        # Apply the restriction logic on each union type, even if we already
        # have a match, so that we can detect ambiguous calls between of
        # literal types against aliases that resolve to union types.
        restriction = common_descendent(type, union_type)
        restricted ||= restriction
      end

      restricted ? type : nil
    end

    private def self.common_descendent_including_types(mod, type)
      mod.including_types.try { |t| common_descendent(t, type) }
    end

    private def self.common_descendent_instance_and_generic(instance, generic)
      instance.parents.try &.each do |parent|
        if parent.module?
          return instance if parent.implements?(generic)
        else
          restricted = common_descendent(parent, generic)
          return instance if restricted
        end
      end
    end

    private def self.common_descendent_generic_instances(type1, type2)
      return nil unless type1.generic_type == type2.generic_type

      type1.type_vars.each do |name, type_var1|
        type_var2 = type2.type_vars[name]
        if type_var1.is_a?(Var) && type_var2.is_a?(Var)
          # type vars are invariant except for Tuple and NamedTuple and those have
          # separate logic
          return nil unless type_var1.type.devirtualize == type_var2.type.devirtualize
        else
          return nil unless type_var1 == type_var2
        end
      end

      type1
    end
  end
end
