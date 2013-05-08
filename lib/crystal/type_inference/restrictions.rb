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
        generic && container.equal?(type.container) && name == type.name && type.type_vars.values.map(&:type).compact.length == 0 ||
        parents.any? { |parent| parent.is_restriction_of?(type, owner) }
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
  end

  class HierarchyType
    def is_restriction_of?(type, owner)
      type.is_subclass_of?(self.base_type) || self.base_type.is_subclass_of?(type)
    end
  end


end