module Crystal
  class Def
    def is_restriction_of?(other, owner)
      args.zip(other.args).each do |self_arg, other_arg|
        self_type = self_arg.type || self_arg.type_restriction
        other_type = other_arg.type || other_arg.type_restriction
        return false if self_type == nil && other_type != nil
        if self_type != nil && other_type != nil
          return false unless self_type.is_restriction_of?(other_type, owner)
        end
      end
      true
    end
  end

  class Ident
    def is_restriction_of?(other, owner)
      return true if self == other

      if other.is_a?(IdentUnion)
        return other.idents.any? { |o| self.is_restriction_of?(o, owner) }
      end

      return false unless other.is_a?(Ident)

      if self_type = owner.lookup_type(names)
        other_type = owner.lookup_type(other.names)

        return other_type == nil || self_type.is_restriction_of?(other_type, owner)
      end

      false
    end
  end

  class NewGenericClass
    def is_restriction_of?(other, owner)
      return true if self == other
      return false unless other.is_a?(NewGenericClass)
      return false unless name == other.name && type_vars.length == other.type_vars.length

      0.upto(type_vars.length - 1) do |i|
        return false unless type_vars[i].is_restriction_of?(other.type_vars[i], owner)
      end

      true
    end
  end

  class Type
    def is_restriction_of?(type, owner)
      type.nil? || equal?(type) ||
        type.is_a?(UnionType) && type.types.any? { |union_type| self.is_restriction_of?(union_type, owner) } ||
        type.is_a?(HierarchyType) && self.is_subclass_of?(type.base_type) ||
        generic? && type.generic? && generic_class.equal?(type) ||
        parents && parents.any? { |parent| parent.is_restriction_of?(type, owner) }
    end

    def is_restriction_of_all?(type)
      if type.is_a?(UnionType)
        type.types.all? { |subtype| is_restriction_of? subtype, subtype }
      else
        is_restriction_of? type, type
      end
    end

    def restrict(other)
      ((other.nil? || equal?(other)) && self) ||
      (other.is_a?(UnionType) && other.types.any? { |union_type| self.is_restriction_of?(union_type, nil) } && self) ||
      (other.is_a?(HierarchyType) && self.is_subclass_of?(other.base_type) && self) ||
      (generic? && other.generic? && generic_class.equal?(other) && self) ||
      (parents && parents.any? { |parent| parent.is_restriction_of?(other, nil) } && self) ||
      nil
    end
  end

  module InheritableClass
    def is_restriction_of?(type, owner)
      if type && type.is_a?(InheritableClass)
        if (depth < type.depth) || (depth == type.depth && !equal?(type))
          return false
        end
      end
      super
    end
  end

  class SelfType
    def is_restriction_of?(type, owner)
      owner.is_restriction_of?(type, owner)
    end
  end

  class UnionType
    def is_restriction_of?(type, owner)
      types.any? { |sub| sub.is_restriction_of?(type, owner) }
    end

    def restrict(type)
      program.type_merge(*types.map { |sub| sub.restrict(type) })
    end
  end

  class HierarchyType
    def is_restriction_of?(other, owner)
      other = other.base_type if other.is_a?(HierarchyType)
      self.base_type.is_subclass_of?(other)
    end

    def restrict(other)
      if equal?(other)
        self
      elsif other.is_a?(UnionType)
        program.type_merge *other.types.map { |t| self.restrict(t) }
      elsif other.hierarchy?
        result = base_type.restrict(other.base_type) || other.base_type.restrict(base_type)
        result ? result.hierarchy_type : nil
      elsif other.is_subclass_of?(self.base_type)
        other.hierarchy_type
      elsif self.base_type.is_subclass_of?(other)
        self
      elsif other.module?
        if base_type.implements?(other)
          self
        else
          types = base_type.subclasses.map do |subclass|
            subclass.hierarchy_type.restrict(other)
          end
          program.type_merge_union_of *types
        end
      else
        nil
      end
    end

    def is_subclass_of?(other)
      base_type.is_subclass_of?(other)
    end
  end
end
