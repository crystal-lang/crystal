require "../program"

module Crystal
  class Program
    def type_merge(types : Array(Type?)) : Type?
      case types.size
      when 0
        nil
      when 1
        types.first
      when 2
        # Merging two types is the most common case, so we optimize it
        first, second = types
        type_merge(first, second)
      else
        combined_union_of compact_types(types)
      end
    end

    def type_merge(nodes : Enumerable(ASTNode)) : Type?
      case nodes.size
      when 0
        nil
      when 1
        nodes.first.type?
      when 2
        # Merging two types is the most common case, so we optimize it
        # We use `#each_cons_pair` to avoid any intermediate allocation
        nodes.each_cons_pair do |first, second|
          return type_merge(first.type?, second.type?)
        end
      else
        combined_union_of compact_types(nodes, &.type?)
      end
    end

    def type_merge(first : Type?, second : Type?) : Type?
      # Same, so return any of them
      return first if first == second

      # First is nil, so return second
      return second unless first

      # Second is nil, so return first
      return first unless second

      # NoReturn is removed from unions
      return second if first.no_return?
      return first if second.no_return?

      if first.nil_type? && second.is_a?(UnionType) && second.union_types.includes?(first)
        return second
      end

      if second.nil_type? && first.is_a?(UnionType) && first.union_types.includes?(second)
        return first
      end

      # General case
      combined_union_of compact_types({first, second})
    end

    def type_merge_union_of(types : Array(Type)) : Type?
      union_of compact_types(types)
    end

    def compact_types(types) : Array(Type)
      compact_types(types) { |type| type }
    end

    def compact_types(objects, &) : Array(Type)
      all_types = Array(Type).new(objects.size)
      objects.each { |obj| add_type all_types, yield(obj) }
      all_types.reject! &.no_return? if all_types.size > 1
      all_types
    end

    def add_type(types, type : UnionType)
      type.union_types.each do |subtype|
        add_type types, subtype
      end
    end

    def add_type(types, type : AliasType)
      aliased = type.remove_alias
      if aliased == type
        types << type unless types.includes? type
      else
        add_type types, aliased
      end
    end

    # When Void participates in a union, it becomes Nil
    # (users shouldn't deal with real Void values)
    def add_type(types, type : VoidType)
      add_type(types, nil_type)
    end

    def add_type(types, type : Type)
      types << type unless types.includes? type
    end

    def add_type(set, type : Nil)
      # Nothing to do
    end

    def combined_union_of(types : Array)
      case types.size
      when 0
        nil
      when 1
        types.first
      else
        combined_types = type_combine types
        union_of combined_types
      end
    end

    def type_combine(types)
      all_types = [types.shift] of Type

      types.each do |t2|
        not_found = all_types.all? do |t1|
          ancestor = Type.least_common_ancestor(t1.devirtualize, t2.devirtualize)
          if ancestor && virtual_root?(ancestor)
            all_types.delete t1
            all_types << ancestor.virtual_type
            false
          else
            true
          end
        end
        if not_found
          all_types << t2
        end
      end

      all_types
    end

    # Returns true if *type* can be used as a virtual root; that is, it must not
    # be one of Object, Reference, Value, Struct, Number, Int, Float, or their
    # corresponding metaclasses.
    def virtual_root?(type)
      # This discards Object, Reference and Value
      return false if type.is_a?(ClassType) && type.depth <= 1

      case type
      when self.struct, self.number, self.int, self.float
        false
      else
        true
      end
    end

    def virtual_root?(type : VirtualType | VirtualMetaclassType)
      virtual_root?(type.base_type)
    end

    def virtual_root?(type : MetaclassType | GenericClassInstanceMetaclassType | GenericModuleInstanceMetaclassType)
      virtual_root?(type.instance_type)
    end
  end

  class Type
    def self.merge(nodes : Enumerable(ASTNode)) : Type?
      nodes.find(&.type?).try &.type.program.type_merge(nodes)
    end

    def self.merge(types : Array(Type)) : Type?
      if types.size == 0
        nil
      else
        types.first.program.type_merge(types)
      end
    end

    def self.merge!(types_or_nodes) : Type
      merge(types_or_nodes).not_nil!
    end

    def self.merge!(type1 : Type, type2 : Type) : Type
      type1.program.type_merge(type1, type2).not_nil!
    end

    # Given two non-union types T and U, returns their least common ancestor
    # LCA(T, U) such that the following properties are satisfied:
    #
    # * LCA(T, U) is never a union;
    # * LCA(T, U) is never virtual, since `#type_combine` takes care of this;
    # * T <= LCA(T, U) and U <= LCA(T, U);
    # * for any type V, if T <= V and U <= V, then LCA(T, U) <= V;
    # * LCA is commutative up to equivalence; that is, if V = LCA(T, U) and
    #   W = LCA(U, T), then V <= W and W <= V;
    # * LCA is associative up to equivalence.
    #
    # If such a type exists and this type can be used as a virtual root (see
    # `Program#virtual_root?`), then T | U is precisely the virtual type of
    # LCA(T, U). Otherwise, T | U is an irreducible union and this method should
    # return `nil`.
    #
    # The above applies only if T and U are unequal; this is guaranteed by
    # `Program#add_type`, so T | T produces a non-virtual type. However, this
    # method should not break in case it recursively calls itself with two
    # identical types.
    def self.least_common_ancestor(type1 : Type, type2 : Type)
      nil
    end

    def self.least_common_ancestor(
      type1 : MetaclassType | GenericClassInstanceMetaclassType,
      type2 : MetaclassType | GenericClassInstanceMetaclassType,
    )
      return nil unless unifiable_metaclass?(type1) && unifiable_metaclass?(type2)

      common = least_common_ancestor(type1.instance_type, type2.instance_type)
      common.try &.metaclass
    end

    def self.least_common_ancestor(type1 : NonGenericModuleType | GenericModuleInstanceType | GenericClassType, type2 : Type)
      type1 if type2.implements?(type1)
    end

    def self.least_common_ancestor(type1 : Type, type2 : NonGenericModuleType | GenericModuleInstanceType | GenericClassType)
      type2 if type1.implements?(type2)
    end

    def self.least_common_ancestor(
      type1 : NonGenericModuleType | GenericModuleInstanceType | GenericClassType,
      type2 : NonGenericModuleType | GenericModuleInstanceType | GenericClassType,
    )
      return type2 if type1.implements?(type2)
      return type1 if type2.implements?(type1)
    end

    def self.least_common_ancestor(type1 : GenericClassType, type2 : ClassType | GenericClassInstanceType)
      return type2 if type1.implements?(type2)
      return type1 if type2.implements?(type1)
    end

    def self.least_common_ancestor(type1 : ClassType | GenericClassInstanceType, type2 : GenericClassType)
      return type1 if type2.implements?(type1)
      return type2 if type1.implements?(type2)
    end

    def self.least_common_ancestor(type1 : ClassType | GenericClassInstanceType, type2 : ClassType | GenericClassInstanceType)
      return type1 if type1 == type2

      if type1.depth == type2.depth
        t1_superclass = type1.superclass
        t2_superclass = type2.superclass

        if t1_superclass && t2_superclass
          return least_common_ancestor(t1_superclass, t2_superclass)
        end
      elsif type1.depth > type2.depth
        t1_superclass = type1.superclass
        if t1_superclass
          return least_common_ancestor(t1_superclass, type2)
        end
      elsif type1.depth < type2.depth
        t2_superclass = type2.superclass
        if t2_superclass
          return least_common_ancestor(type1, t2_superclass)
        end
      end

      nil
    end

    def self.least_common_ancestor(type1 : TupleInstanceType, type2 : TupleInstanceType)
      return nil unless type1.size == type2.size

      result_types = type1.tuple_types.map_with_index do |self_tuple_type, index|
        merge!(self_tuple_type, type2.tuple_types[index]).as(Type)
      end
      type1.program.tuple_of(result_types)
    end

    def self.least_common_ancestor(type1 : NamedTupleInstanceType, type2 : NamedTupleInstanceType)
      return nil if type1.size != type2.size

      self_entries = type1.entries.sort_by &.name
      other_entries = type2.entries.sort_by &.name

      # First check if the names are the same
      self_entries.zip(other_entries) do |self_entry, other_entry|
        return nil unless self_entry.name == other_entry.name
      end

      # If the names are the same we now merge the types for each key
      # NOTE: we use self's order to preserve the order of the tuple on the left hand side
      merged_entries = type1.entries.map_with_index do |self_entry, i|
        name = self_entry.name
        other_type = type2.name_type(name)
        merged_type = merge!(self_entry.type, other_type).as(Type)
        NamedArgumentType.new(name, merged_type)
      end

      type1.program.named_tuple_of(merged_entries)
    end

    private def self.unifiable_metaclass?(type)
      case type.instance_type
      when .module?
        false # Module metaclasses are never unified
      when UnionType
        false # Union metaclasses are never unified
      when TupleInstanceType
        false # Tuple instances might be unified, but never tuple metaclasses
      when NamedTupleInstanceType
        false # Named tuple instances might be unified, but never named tuple metaclasses
      else
        true
      end
    end
  end
end
