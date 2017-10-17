require "../program"

module Crystal
  class Program
    def type_merge(types : Array(Type?))
      case types.size
      when 0
        return nil
      when 1
        return types.first
      when 2
        # Merging two types is the most common case, so we optimize it
        first, second = types
        did_merge, merged_type = type_merge_two(first, second)
        return merged_type if did_merge
      end

      combined_union_of compact_types(types)
    end

    def type_merge(nodes : Array(ASTNode))
      case nodes.size
      when 0
        return nil
      when 1
        return nodes.first.type?
      when 2
        # Merging two types is the most common case, so we optimize it
        first, second = nodes
        did_merge, merged_type = type_merge_two(first.type?, second.type?)
        return merged_type if did_merge
      end

      combined_union_of compact_types(nodes, &.type?)
    end

    def type_merge_two(first, second)
      if first == second
        # Same, so return any of them
        {true, first}
      elsif first
        if second
          # first and second not nil and different
          if first.opaque_id > second.opaque_id
            first, second = second, first
          end

          if first.nil_type?
            if second.is_a?(UnionType) && second.union_types.includes?(first)
              return true, second
            end
          end

          # puts "#{first} vs. #{second}"
          {false, nil}
        else
          # Second is nil, so return first
          {true, first}
        end
      else
        # First is nil, so return second
        {true, second}
      end
    end

    def type_merge_union_of(types : Array(Type))
      union_of compact_types(types)
    end

    def compact_types(types)
      compact_types(types) { |type| type }
    end

    def compact_types(objects)
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
          ancestor = t1.common_ancestor(t2)
          if ancestor
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
  end

  class Type
    def self.merge(nodes : Array(ASTNode))
      nodes.find(&.type?).try &.type.program.type_merge(nodes)
    end

    def self.merge(types : Array(Type))
      if types.size == 0
        nil
      else
        types.first.program.type_merge(types)
      end
    end

    def self.merge!(types_or_nodes)
      merge(types_or_nodes).not_nil!
    end

    def self.merge!(type1 : Type, type2 : Type)
      merge!([type1, type2])
    end

    def common_ancestor(other)
      nil
    end
  end

  class NonGenericModuleType
    def common_ancestor(other : Type)
      if other.implements?(self)
        self
      else
        nil
      end
    end
  end

  class GenericModuleInstanceType
    def common_ancestor(other : Type)
      if other.implements?(self)
        self
      else
        nil
      end
    end
  end

  class GenericClassType
    def common_ancestor(other : Type)
      if other.implements?(self)
        self
      else
        nil
      end
    end
  end

  class ClassType
    def common_ancestor(other : ClassType | GenericClassInstanceType)
      class_common_ancestor(self, other)
    end

    def common_ancestor(other : VirtualType)
      common_ancestor(other.base_type)
    end

    def common_ancestor(other : NonGenericModuleType | GenericModuleInstanceType)
      other.common_ancestor(self)
    end
  end

  class GenericClassInstanceType
    def common_ancestor(other : ClassType | GenericClassInstanceType)
      class_common_ancestor(self, other)
    end

    def common_ancestor(other : VirtualType)
      common_ancestor(other.base_type)
    end

    def common_ancestor(other : NonGenericModuleType | GenericModuleInstanceType)
      other.common_ancestor(self)
    end
  end

  class MetaclassType
    def common_ancestor(other : MetaclassType | VirtualMetaclassType | GenericClassInstanceMetaclassType)
      if instance_type.module? || other.instance_type.module?
        nil
      else
        common = instance_type.common_ancestor(other.instance_type)
        common.try &.metaclass
      end
    end
  end

  class GenericClassInstanceMetaclassType
    def common_ancestor(other : MetaclassType | VirtualMetaclassType | GenericClassInstanceMetaclassType)
      if instance_type.module? || other.instance_type.module?
        nil
      else
        common = instance_type.common_ancestor(other.instance_type)
        common.try &.metaclass
      end
    end
  end

  class PrimitiveType
    def common_ancestor(other)
      nil
    end
  end

  class VirtualType
    def common_ancestor(other)
      base_type.common_ancestor(other)
    end
  end

  class VirtualMetaclassType
    def common_ancestor(other : MetaclassType | VirtualMetaclassType)
      common = instance_type.base_type.metaclass.common_ancestor(other)
      common.try &.virtual_type!
    end
  end

  class ProcInstanceType
    def common_ancestor(other : ProcInstanceType)
      if return_type.no_return? && arg_types == other.arg_types
        return other
      end

      if other.return_type.no_return? && arg_types == other.arg_types
        return self
      end

      nil
    end
  end

  class TupleInstanceType
    def common_ancestor(other : TupleInstanceType)
      return nil unless self.size == other.size

      result_types = tuple_types.map_with_index do |self_tuple_type, index|
        Type.merge!(self_tuple_type, other.tuple_types[index]).as(Type)
      end
      program.tuple_of(result_types)
    end
  end

  class NamedTupleInstanceType
    def common_ancestor(other : NamedTupleInstanceType)
      return nil if self.size != other.size

      self_entries = self.entries.sort_by &.name
      other_entries = other.entries.sort_by &.name

      # First check if the names are the same
      self_entries.zip(other_entries) do |self_entry, other_entry|
        return nil unless self_entry.name == other_entry.name
      end

      # If the names are the same we now merge the types for each key
      # NOTE: we use self's order to preserve the order of the tuple on the left hand side
      merged_entries = self.entries.map_with_index do |self_entry, i|
        name = self_entry.name
        other_type = other.name_type(name)
        merged_type = Type.merge!(self_entry.type, other_type).as(Type)
        NamedArgumentType.new(name, merged_type)
      end

      program.named_tuple_of(merged_entries)
    end
  end
end

private def class_common_ancestor(t1, t2)
  # This discards Object, Reference and Value
  if t1.depth <= 1
    return nil
  end

  case t1
  when t1.program.struct, t1.program.number, t1.program.int, t1.program.float
    return nil
  when t2
    return t1
  end

  if t1.depth == t2.depth
    t1_superclass = t1.superclass
    t2_superclass = t2.superclass

    if t1_superclass && t2_superclass
      return t1_superclass.common_ancestor(t2_superclass)
    end
  elsif t1.depth > t2.depth
    t1_superclass = t1.superclass
    if t1_superclass
      return t1_superclass.common_ancestor(t2)
    end
  elsif t1.depth < t2.depth
    t2_superclass = t2.superclass
    if t2_superclass
      return t1.common_ancestor(t2_superclass)
    end
  end

  nil
end
