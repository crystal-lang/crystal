module Crystal
  class Type
    # Looks up a *path* (for example: `Foo::Bar::Baz`) relative to `self`.
    #
    # For example, given:
    #
    # ```
    # class Foo
    #   class Bar
    #     class Baz
    #     end
    #   end
    # end
    # ```
    #
    # If `self` is `Foo` and we invoke `lookup_path(["Bar", "Baz"])` on it,
    # we'll get `Foo::Bar::Baz` as the return value.
    #
    # The path is searched in the current type's ancestors, and optionally
    # in its namespace, according to *lookup_in_namespace*.
    #
    # Returns `nil` if the path can't be found.
    #
    # The result can be an ASTNode in the case the path denotes a type variable
    # whose variable is an ASTNode. One such example is the `N` of `StaticArray(T, N)`
    # for some instantiated `StaticArray`.
    #
    # If the path is global (for example ::Foo::Bar), the search starts at
    # the top level.
    def lookup_path(path : Path, lookup_in_namespace = true) : Type | ASTNode | Nil
      (path.global? ? program : self).lookup_path(path.names, lookup_in_namespace: lookup_in_namespace)
    rescue ex : Crystal::Exception
      raise ex
    rescue ex
      path.raise ex.message
    end

    # ditto
    def lookup_path(path : Array(String), lookup_in_namespace = true) : Type | ASTNode | Nil
      raise "Bug: #{self} doesn't implement lookup_path"
    end
  end

  class NamedType
    def lookup_path(names : Array, lookup_in_namespace = true)
      type = self
      names.each_with_index do |name, i|
        next_type = type.types?.try &.[name]?
        if !next_type && i != 0
          # Once we find a first type we search in it and don't backtrack
          return type.lookup_path_in_parents(names[i..-1])
        end
        type = next_type
        break unless type
      end

      return type if type

      parent_match = lookup_path_in_parents(names)
      return parent_match if parent_match

      lookup_in_namespace && self != program ? namespace.lookup_path(names) : nil
    end

    protected def lookup_path_in_parents(names : Array, lookup_in_namespace = false)
      parents.try &.each do |parent|
        match = parent.lookup_path(names, lookup_in_namespace)
        return match if match.is_a?(Type)
      end
      nil
    end
  end

  module GenericType
    def lookup_path(names : Array, lookup_in_namespace = true)
      # If we are Foo(T) and somebody looks up the type T, we return `nil` because we don't
      # know what type T is, and we don't want to continue search in the namespace
      if !names.empty? && type_vars.includes?(names[0])
        return nil
      end
      super
    end
  end

  class GenericClassInstanceType
    def lookup_path(names : Array, lookup_in_namespace = true)
      if !names.empty? && (type_var = type_vars[names[0]]?)
        case type_var
        when Var
          type_var_type = type_var.type
        else
          type_var_type = type_var
        end

        if names.size > 1
          if type_var_type.is_a?(Type)
            type_var_type.lookup_path(names[1..-1], lookup_in_namespace)
          else
            raise "#{names[0]} is not a type, it's #{type_var_type}"
          end
        else
          type_var_type
        end
      else
        generic_class.lookup_path(names, lookup_in_namespace)
      end
    end
  end

  class IncludedGenericModule
    def lookup_path(names : Array, lookup_in_namespace = true)
      if (names.size == 1) && (m = @mapping[names[0]]?)
        # Case of a variadic tuple
        if m.is_a?(TupleLiteral)
          types = m.elements.map do |element|
            @including_class.lookup_type(element).as(Type)
          end
          return program.tuple_of(types)
        end

        case @including_class
        when GenericClassType, GenericModuleType
          # skip
        else
          return @including_class.lookup_type(m)
        end
      end

      @module.lookup_path(names, lookup_in_namespace)
    end
  end

  class InheritedGenericClass
    def lookup_path(names : Array, lookup_in_namespace = true)
      if (names.size == 1) && (m = @mapping[names[0]]?)
        extending_class = self.extending_class
        case extending_class
        when GenericClassType
          # skip
        else
          if extending_class.is_a?(NamedType)
            self_type = extending_class.namespace
          else
            self_type = extending_class.program
          end
          return extending_class.lookup_type(m, self_type: self_type)
        end
      end

      @extended_class.lookup_path(names, lookup_in_namespace)
    end
  end

  class UnionType
    def lookup_path(names : Array, lookup_in_namespace = true)
      if names.size == 1 && names[0] == "T"
        return program.tuple_of(union_types)
      end
      program.lookup_path(names, lookup_in_namespace)
    end
  end

  class TypeDefType
    delegate lookup_path, to: typedef
  end

  class MetaclassType
    delegate lookup_path, to: instance_type
  end

  class GenericClassInstanceMetaclassType
    delegate lookup_path, to: instance_type
  end

  class VirtualType
    delegate lookup_path, to: base_type
  end

  class VirtualMetaclassType
    delegate lookup_path, to: instance_type
  end
end
