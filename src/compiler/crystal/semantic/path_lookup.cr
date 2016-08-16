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
    # The result can be an `ASTNode` in the case the path denotes a type variable
    # whose variable is an `ASTNode`. One such example is the `N` of `StaticArray(T, N)`
    # for some instantiated `StaticArray`.
    #
    # If the path is global (for example ::Foo::Bar), the search starts at
    # the top level.
    def lookup_path(path : Path, lookup_in_namespace = true) : Type | ASTNode | Nil
      (path.global? ? program : self).lookup_path(path.names, lookup_in_namespace: lookup_in_namespace)
    end

    # ditto
    def lookup_path(names : Array(String), lookup_in_namespace = true) : Type | ASTNode | Nil
      type = self
      names.each_with_index do |name, i|
        # The search must continue in the namespace only for the first path
        # item: for subsequent path items only the parents must be looked up
        type = type.lookup_path_item(name, lookup_in_namespace: lookup_in_namespace && i == 0)
        return unless type

        # Stop if this is the last name
        break if i == names.size - 1

        # An intermediate match could be an ASTNode, for example
        # when searching T::N::X, and T denotes a static array:
        # in this case we can't continue searching past `N`
        return unless type.is_a?(Type)
      end
      type
    end

    # Looks up a single path item relative to *self`.
    #
    # If *lookup_in_namespace* is `true`, if the type is not found
    # in `self` or `self`'s parents, the path item is searched in this
    # type's namespace. This parameter is useful because when writing
    # `Foo::Bar::Baz`, `Foo` should be searched in enclosing namespaces,
    # but `Bar` and `Baz` not.
    def lookup_path_item(name : String, lookup_in_namespace) : Type | ASTNode | Nil
      # First search in our types
      type = types?.try &.[name]?
      return type if type

      # Then try out parents, but don't search in our parents namespace
      parents.try &.each do |parent|
        match = parent.lookup_path_item(name, lookup_in_namespace: false)
        return match if match
      end

      # Try our namespace, unless we are the top-level
      if lookup_in_namespace && self != program
        return namespace.lookup_path_item(name, lookup_in_namespace)
      end

      nil
    end
  end

  module GenericType
    def lookup_path_item(name : String, lookup_in_namespace)
      # If we are Foo(T) and somebody looks up the type T, we return `nil` because we don't
      # know what type T is, and we don't want to continue search in the namespace
      if type_vars.includes?(name)
        return nil
      end
      super
    end
  end

  class GenericClassInstanceType
    def lookup_path_item(name : String, lookup_in_namespace)
      # Check if *name* is a type variable
      if type_var = type_vars[name]?
        if type_var.is_a?(Var)
          type_var.type
        else
          type_var
        end
      else
        generic_class.lookup_path_item(name, lookup_in_namespace)
      end
    end
  end

  class IncludedGenericModule
    def lookup_path_item(name : String, lookup_in_namespace)
      if m = @mapping[name]?
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

      @module.lookup_path_item(name, lookup_in_namespace)
    end
  end

  class InheritedGenericClass
    def lookup_path_item(name : String, lookup_in_namespace)
      if m = @mapping[name]?
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

      @extended_class.lookup_path_item(name, lookup_in_namespace)
    end
  end

  class UnionType
    def lookup_path_item(name : String, lookup_in_namespace)
      # Union type does not currently inherit GenericClassInstanceType,
      # so we check if *name* is the only type variable of Union(*T)
      if name == "T"
        return program.tuple_of(union_types)
      end
      program.lookup_path_item(name, lookup_in_namespace)
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
