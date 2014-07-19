require "../ast"
require "../types"

module Crystal
  class ASTNode
    def is_restriction_of?(other : ASTNode, owner)
      self == other
    end

    def is_restriction_of?(other, owner)
      raise "Bug: called #{self}.is_restriction_of?(#{other})"
    end
  end

  class Self
    def is_restriction_of?(type : Type, owner)
      owner.is_restriction_of?(type, owner)
    end

    def is_restriction_of?(type : Self, owner)
      true
    end

    def is_restriction_of?(type : ASTNode, owner)
      false
    end
  end

  class Def
    def is_restriction_of?(other : Def, owner)
      args.zip(other.args) do |self_arg, other_arg|
        self_type = self_arg.type? || self_arg.restriction
        other_type = other_arg.type? || other_arg.restriction
        return false if self_type == nil && other_type != nil
        if self_type && other_type
          return false unless self_type.is_restriction_of?(other_type, owner)
        end
      end
      true
    end
  end


  class Path
    def is_restriction_of?(other : Path, owner)
      return true if self == other

      self_type = owner.lookup_type(self)
      if self_type
        other_type = owner.lookup_type(other)
        if other_type
          return self_type.is_restriction_of?(other_type, owner)
        else
          return true
        end
      end

      false
    end

    def is_restriction_of?(other : Union, owner)
      other.types.any? { |o| self.is_restriction_of?(o, owner) }
    end

    def is_restriction_of?(other, owner)
      false
    end
  end

  class Union
    def is_restriction_of?(other : Path, owner)
      !other.is_restriction_of?(self, owner)
    end
  end

  class Generic
    def is_restriction_of?(other : Generic, owner)
      return true if self == other
      return false unless name == other.name && type_vars.length == other.type_vars.length

      type_vars.zip(other.type_vars) do |type_var, other_type_var|
        return false unless type_var.is_restriction_of?(other_type_var, owner)
      end

      true
    end
  end

  class Type
    def restrict(other : Nil, context)
      self
    end

    def restrict(other : Type, context)
      if self == other
        return self
      end

      if parents.try &.any? &.is_restriction_of?(other, nil)
        return self
      end

      nil
    end

    def restrict(other : AliasType, context)
      if self == other
        self
      else
        restrict(other.remove_alias, context)
      end
    end

    def restrict(other : Self, context)
      restrict(context.owner, context)
    end

    def restrict(other : UnionType, context)
      restricted = other.union_types.any? { |union_type| is_restriction_of?(union_type, context.owner) }
      restricted ? self : nil
    end

    def restrict(other : HierarchyType, context)
      is_subclass_of?(other.base_type) ? self : nil
    end

    def restrict(other : Union, context)
      types = [] of Type
      other.types.each do |ident|
        restricted = restrict ident, context
        types << restricted if restricted
      end
      types.length > 0 ? program.type_merge_union_of(types) : nil
    end

    def restrict(other : Path, context)
      single_name = other.names.length == 1
      if single_name
        ident_type = context.get_free_var(other.names.first)
      end

      ident_type ||= context.type_lookup.lookup_type other
      if ident_type
        restrict ident_type, context
      elsif single_name
        context.set_free_var(other.names.first, self)
      else
        self
      end
    end

    def restrict(other : Generic, context)
      parents.try &.each do |parent|
        restricted = parent.restrict other, context
        return self if restricted
      end

      nil
    end

    def restrict(other : Metaclass, context)
      nil
    end

    def restrict(other : Fun, context)
      nil
    end

    def restrict(other : Underscore, context)
      self
    end

    def restrict(other : ASTNode, context)
      raise "Bug: unsupported restriction: #{self} vs. #{other}"
    end

    def is_restriction_of?(other : UnionType, owner)
      other.union_types.any? { |subtype| is_restriction_of?(subtype, owner) }
    end

    def is_restriction_of?(other : HierarchyType, owner)
      is_subclass_of? other.base_type
    end

    def is_restriction_of?(other : Type, owner)
      if self == other
        return true
      end

      if (parents = self.parents) && parents.length > 0
        return parents.any? &.is_restriction_of?(other, owner)
      end

      false
    end

    def is_restriction_of?(other : AliasType, owner)
      if self == other
        true
      else
        is_restriction_of?(other.remove_alias, owner)
      end
    end

    def is_restriction_of?(other : ASTNode, owner)
      raise "Bug: called #{self}.is_restriction_of?(#{other})"
    end

    def is_restriction_of_all?(type : UnionType)
      type.union_types.all? { |subtype| is_restriction_of? subtype, subtype }
    end

    def is_restriction_of_all?(type)
      is_restriction_of? type, type
    end

    def compatible_with?(type)
      self == type
    end
  end

  class IntegerType
    def restrict(other : CEnumType, context)
      self == other.base_type ? self : nil
    end
  end

  class UnionType
    def is_restriction_of?(type, owner)
      self == type || union_types.any? &.is_restriction_of?(type, owner)
    end

    def restrict(other : Union, context)
      types = [] of Type
      discarded = [] of Type
      other.types.each do |other_type|
        self.union_types.each do |type|
          next if discarded.includes?(type)

          restricted = type.restrict(other_type, context)
          if restricted
            types << restricted
            discarded << type
            break
          end
        end
      end
      program.type_merge_union_of(types)
    end

    def restrict(other : Type, context)
      restrict_type_or_fun_or_generic other, context
    end

    def restrict(other : Fun, context)
      restrict_type_or_fun_or_generic other, context
    end

    def restrict(other : Generic, context)
      restrict_type_or_fun_or_generic other, context
    end

    def restrict_type_or_fun_or_generic(other, context)
      types = [] of Type
      union_types.each do |type|
        restricted = type.restrict(other, context)
        types << restricted if restricted
      end
      program.type_merge_union_of(types)
    end
  end

  class GenericClassInstanceType
    def restrict(other : Path, context)
      ident_type = context.type_lookup.lookup_type other
      if ident_type
        restrict(ident_type, context)
      else
        super
      end
    end

    def restrict(other : GenericClassType, context)
      generic_class == other ? self : nil
    end

    def restrict(other : Generic, context)
      generic_class = context.type_lookup.lookup_type other.name
      return super unless generic_class == self.generic_class

      generic_class = generic_class as GenericClassType
      return nil unless generic_class.type_vars.length == self.generic_class.type_vars.length

      i = 0
      type_vars.each do |name, type_var|
        other_type_var = other.type_vars[i]
        restricted = type_var.type.restrict other_type_var, context
        return nil unless restricted == type_var.type
        i += 1
      end

      self
    end

    def restrict(other : GenericClassInstanceType, context)
      return nil unless generic_class == other.generic_class

      type_vars.each do |name, type_var|
        other_type_var = other.type_vars[name]
        restricted = type_var.type.restrict(other_type_var.type, context)
        return nil unless restricted == type_var.type
      end

      self
    end
  end

  class TupleInstanceType
    def restrict(other : Generic, context)
      generic_class = context.type_lookup.lookup_type other.name
      return super unless generic_class == self.generic_class

      generic_class = generic_class as TupleType
      return nil unless other.type_vars.length == tuple_types.length

      tuple_types.zip(other.type_vars) do |tuple_type, type_var|
        restricted = tuple_type.restrict(type_var, context)
        return nil unless restricted == tuple_type
      end

      self
    end

    def restrict(other : TupleInstanceType, context)
      self == other ? self : nil
    end
  end

  class IncludedGenericModule
    def is_restriction_of?(other : Type, owner)
      @module.is_restriction_of?(other, owner)
    end

    def restrict(other : Generic, context)
      generic_module = context.type_lookup.lookup_type other.name
      return nil unless generic_module == @module

      generic_module = generic_module as GenericModuleType
      return nil unless generic_module.type_vars.length == @module.type_vars.length

      @module.type_vars.zip(other.type_vars) do |module_type_var, other_type_var|
        if m = @mapping[module_type_var]?
          t = TypeLookup.lookup(@including_class, m)
          restricted = t.restrict other_type_var, context
          return nil unless restricted

          context.set_free_var(module_type_var, restricted)
        end
      end

      self
    end
  end

  class HierarchyType
    def is_restriction_of?(other : Type, owner)
      other = other.base_type if other.is_a?(HierarchyType)
      base_type.is_subclass_of?(other) || other.is_subclass_of?(base_type)
    end

    def restrict(other : Type, context)
      if self == other
        self
      elsif other.is_a?(UnionType)
        types = [] of Type
        other.union_types.each do |t|
          restricted = self.restrict(t, context)
          types << restricted if restricted
        end
        program.type_merge types
      elsif other.is_a?(HierarchyType)
        result = base_type.restrict(other.base_type, context) || other.base_type.restrict(base_type, context)
        result ? result.hierarchy_type : nil
      elsif other.is_subclass_of?(self.base_type)
        other.hierarchy_type
      elsif self.base_type.is_subclass_of?(other)
        self
      elsif other.module?
        if base_type.implements?(other)
          self
        else
          types = [] of Type
          base_type.subclasses.each do |subclass|
            restricted = subclass.hierarchy_type.restrict(other, context)
            types << restricted if restricted
          end
          program.type_merge_union_of types
        end
      else
        nil
      end
    end

    def restrict(other : Generic, context)
      types = [] of Type
      base_type.subclasses.each do |subclass|
        restricted = subclass.hierarchy_type.restrict(other, context)
        types << restricted if restricted
      end
      program.type_merge_union_of types
    end
  end

  class AliasType
    def is_restriction_of?(other, owner)
      return true if self == other

      remove_alias.is_restriction_of?(other, owner)
    end

    def restrict(other, context)
      if self == other
        self
      else
        remove_alias.restrict(other, context)
      end
    end
  end

  class MetaclassType
    def restrict(other : Metaclass, context)
      restricted = instance_type.restrict(other.name, context)
      if restricted
        self
      else
        nil
      end
    end

    def restrict(other : HierarchyMetaclassType, context)
      restricted = instance_type.restrict(other.instance_type.base_type, context)
      if restricted
        self
      else
        nil
      end
    end
  end

  class FunInstanceType
    def restrict(other : Fun, context)
      inputs = other.inputs
      inputs_len = inputs ? inputs.length : 0
      output = other.output

      return nil if fun_types.length != inputs_len + 1

      if inputs
        inputs.zip(fun_types) do |input, my_input|
          restricted = my_input.restrict(input, context)
          return nil unless restricted == my_input
        end
      end

      if output
        my_output = fun_types.last
        if my_output.no_return?
          # Ok, NoReturn can be "cast" to anything
        else
          restricted = my_output.restrict(output, context)
          return nil unless restricted == my_output
        end

        self
      else
        program.fun_of(arg_types + [program.void])
      end
    end

    def restrict(other : FunInstanceType, context)
      compatible_with?(other) ? other : nil
    end

    def restrict(other : Generic, context)
      generic_class = context.type_lookup.lookup_type other.name
      return super unless generic_class.is_a?(FunType)

      return nil unless other.type_vars.length == fun_types.length

      fun_types.each_with_index do |fun_type, i|
        other_type_var = other.type_vars[i]
        restricted = fun_type.restrict other_type_var, context
        return nil unless restricted == fun_type
      end

      self
    end

    def compatible_with?(other : FunInstanceType)
      arg_types = arg_types()
      return_type = return_type()
      other_arg_types = other.arg_types()
      other_return_type = other.return_type()

      if return_type == other_return_type
        # Ok
      elsif other_return_type.void?
        # Ok, can cast fun to void
      elsif return_type.no_return?
        # Ok, NoReturn can be "cast" to anything
      else
        return false
      end

      # Disallow casting a function to another one accepting different argument count
      return nil if arg_types.length != other_arg_types.length

      arg_types.zip(other_arg_types) do |arg_type, other_arg_type|
        return false unless arg_type == other_arg_type
      end

      true
    end
  end
end
