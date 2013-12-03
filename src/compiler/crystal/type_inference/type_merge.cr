require "../program"

module Crystal
  class Program
    def type_merge(types : Array(Type))
      combined_union_of compact_types(types)
    end

    def type_merge(nodes : Array(ASTNode))
      combined_union_of compact_types(nodes, &.type?)
    end

    def type_merge_union_of(types : Array(Type))
      union_of compact_types(types)
    end

    def compact_types(types)
      compact_types(types) { |type| type }
    end

    def compact_types(objects)
      all_types = Set(Type).new
      objects.each { |obj| add_type all_types, yield(obj) }
      all_types = all_types.to_a
      all_types.delete_if &.no_return? if all_types.length > 1
      all_types
    end

    def add_type(set, type : UnionType)
      type.union_types.each do |subtype|
        add_type set, subtype
      end
    end

    def add_type(set, type : Type)
      set.add type
    end

    def add_type(set, type : Nil)
      # Nothing to do
    end

    def combined_union_of(types : Array)
      case types.length
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
      # if types.all? &.number?
      #   return [types.max_by &.rank] of Type
      # end

      all_types = [types.shift] of Type

      types.each do |t2|
        not_found = all_types.each do |t1|
          ancestor = t1.common_ancestor(t2)
          if ancestor
            all_types.delete t1
            all_types << ancestor.hierarchy_type
            break
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
      if types.length == 0
        nil
      else
        types.first.program.type_merge(types)
      end
    end

    def common_ancestor(other)
      nil
    end
  end

  class ClassType
    def common_ancestor(other : ClassType)
      if depth <= 1
        return nil
      end

      if self == other
        return self
      end

      if depth == other.depth
        my_superclass = @superclass
        other_superclass = other.superclass

        if my_superclass && other_superclass
          return my_superclass.common_ancestor(other_superclass)
        end
      elsif depth > other.depth
        my_superclass = @superclass
        if my_superclass
          return my_superclass.common_ancestor(other)
        end
      elsif depth < other.depth
        other_superclass = other.superclass
        if other_superclass
          return common_ancestor(other_superclass)
        end
      end

      nil
    end

    def common_ancestor(other : HierarchyType)
      common_ancestor(other.base_type)
    end
  end

  class Metaclass
    def common_ancestor(other : Metaclass)
      nil
    end
  end

  class PrimitiveType
    def common_ancestor(other)
      nil
    end
  end

  class HierarchyType
    def common_ancestor(other)
      base_type.common_ancestor(other)
    end
  end
end
