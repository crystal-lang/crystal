class Crystal::Program
  # The top-level pass resolves a type's superclass and the modules it
  # includes or extends as it declares the type, with the class hierarchy
  # declared so far. A class type argument of a generic ancestor is
  # virtualized only once the class has subclasses, so for a class that
  # gains its first subclass later, the ancestor is an instance with the
  # exact type, while the same generic type written anywhere afterwards
  # resolves to a different instance with the virtual type.
  #
  # Once every type is declared, this replaces each such ancestor with the
  # instance a lookup gives now, so that both are the same type.
  def revirtualize_generic_ancestors : Nil
    visited = Set(UInt64).new
    revirtualize_generic_ancestors(self, visited)
    file_modules.each_value { |file_module| revirtualize_generic_ancestors(file_module, visited) }
  end

  private def revirtualize_generic_ancestors(type : Type, visited : Set(UInt64)) : Nil
    return unless visited.add?(type.object_id)

    revirtualize_parents(type)
    revirtualize_parents(type.metaclass) unless type.metaclass.same?(type)
    type.types?.try &.each_value { |inner| revirtualize_generic_ancestors(inner, visited) }
  end

  private def revirtualize_parents(type : Type) : Nil
    return unless type.is_a?(ModuleType)

    type.parents.dup.each do |parent|
      next unless parent.is_a?(GenericInstanceType)

      revirtualized = parent.revirtualized
      type.replace_generic_parent(parent, revirtualized) unless revirtualized.same?(parent)
    end
  end
end
