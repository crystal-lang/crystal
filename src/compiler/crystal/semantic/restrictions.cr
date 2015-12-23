require "../syntax/ast"
require "../types"

module Crystal
  class ASTNode
    def is_restriction_of?(other : Underscore, owner)
      true
    end

    def is_restriction_of?(other : ASTNode, owner)
      self == other
    end

    def is_restriction_of?(other : Type, owner)
      false
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

  struct DefWithMetadata
    def is_restriction_of?(other : DefWithMetadata, owner)
      # If one yields and the other doesn't, none is stricter than the other
      return false unless yields == other.yields

      # A def with more required arguments than the other comes first
      if min_size > other.max_size
        return true
      elsif other.min_size > max_size
        return false
      end

      self_splat_index = self.def.splat_index
      other_splat_index = other.def.splat_index

      # If I splat but the other doesn't, I come later
      if self_splat_index && !other_splat_index
        return false
      end

      # If the other splats but I don't, I come first
      if other_splat_index && !self_splat_index
        return true
      end

      if self_splat_index && other_splat_index
        min = Math.min(min_size, other.min_size)
      else
        min = Math.min(max_size, other.max_size)
      end

      (0...min).each do |index|
        self_arg = self.def.args[index]
        other_arg = other.def.args[index]

        self_type = self_arg.type? || self_arg.restriction
        other_type = other_arg.type? || other_arg.restriction
        return false if self_type == nil && other_type != nil
        if self_type && other_type
          # If this is a splat arg and the other not, this is not stricter than the other
          return false if index == self.def.splat_index

          return false unless self_type.is_restriction_of?(other_type, owner)
        end
      end

      if self_splat_index && other_splat_index
        if self_splat_index == other_splat_index
          self_arg = self.def.args[self_splat_index]
          other_arg = other.def.args[other_splat_index]

          if (self_restriction = self_arg.restriction) && (other_restriction = other_arg.restriction)
            return false unless self_restriction.is_restriction_of?(other_restriction, owner)
          end
        elsif self_splat_index < other_splat_index
          return false
        else
          return true
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
      types.any? &.is_restriction_of?(other, owner)
    end
  end

  class Generic
    def is_restriction_of?(other : Generic, owner)
      return true if self == other
      return false unless name == other.name && type_vars.size == other.type_vars.size

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

      if parents.try &.any? &.is_restriction_of?(other, context.owner)
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
      restrict(context.owner.instance_type, context)
    end

    def restrict(other : TypeOf, context)
      lookup = TypeLookup.new self, context.owner.instance_type
      other.accept lookup
      restrict lookup.type.not_nil!, context
    end

    def restrict(other : UnionType, context)
      restricted = other.union_types.any? { |union_type| is_restriction_of?(union_type, context.owner) }
      restricted ? self : nil
    end

    def restrict(other : VirtualType, context)
      is_subclass_of?(other.base_type) ? self : nil
    end

    def restrict(other : Union, context)
      types = other.types.compact_map do |ident|
        restrict(ident, context) as Type?
      end
      types.size > 0 ? program.type_merge_union_of(types) : nil
    end

    def restrict(other : Path, context)
      single_name = other.names.size == 1
      if single_name
        owner = context.owner

        # Special case: if we have an *uninstantiated* generic type like Foo(X)
        # and a restriction X, it matches, and we add X to the free vars.
        if owner.is_a?(GenericType)
          first_name = other.names.first
          if owner.type_vars.includes?(first_name)
            context.set_free_var(first_name, self)
            return self
          end
        end

        ident_type = context.get_free_var(other.names.first)
      end

      ident_type ||= context.type_lookup.lookup_type other

      if ident_type
        restrict ident_type, context
      elsif single_name
        if Parser.free_var_name?(other.names.first)
          context.set_free_var(other.names.first, self)
        else
          other.raise "undefined constant #{other}"
        end
      else
        other.raise "undefined constant #{other}"
      end
    end

    def restrict(other : Generic, context)
      parents.try &.each do |parent|
        next if parent.is_a?(NonGenericModuleType)

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

    def is_restriction_of?(other : VirtualType, owner)
      is_subclass_of? other.base_type
    end

    def is_restriction_of?(other : Type, owner)
      if self == other
        return true
      end

      parents.try &.any? &.is_restriction_of?(other, owner)
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
      is_restriction_of?(type, type) || type.implements?(self)
    end

    def compatible_with?(type)
      self == type
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
      types = union_types.compact_map do |type|
        type.restrict(other, context) as Type?
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
      generic_class == other ? self : super
    end

    def restrict(other : Generic, context)
      generic_class = context.type_lookup.lookup_type other.name
      return super unless generic_class == self.generic_class

      generic_class = generic_class as GenericClassType

      if generic_class.type_vars.size != other.type_vars.size
        other.raise "wrong number of type vars for #{generic_class} (#{other.type_vars.size} for #{generic_class.type_vars.size})"
      end

      i = 0
      type_vars.each do |name, type_var|
        other_type_var = other.type_vars[i]
        restricted = restrict_type_var(type_var, other_type_var, context)
        return nil unless restricted
        i += 1
      end

      self
    end

    def restrict(other : GenericClassInstanceType, context)
      return super unless generic_class == other.generic_class

      type_vars.each do |name, type_var|
        other_type_var = other.type_vars[name]
        restricted = restrict_type_var(type_var, other_type_var, context)
        return super unless restricted
      end

      self
    end

    def restrict_type_var(type_var, other_type_var, context)
      unless type_var.is_a?(NumberLiteral)
        type_var = type_var.type? || type_var
      end

      unless other_type_var.is_a?(NumberLiteral)
        other_type_var = other_type_var.type? || other_type_var
      end

      if type_var.is_a?(ASTNode)
        type_var.is_restriction_of?(other_type_var, context.owner)
      elsif context.strict?
        type_var == other_type_var
      else
        type_var.restrict(other_type_var, context) == type_var
      end
    end
  end

  class TupleInstanceType
    def restrict(other : Generic, context)
      generic_class = context.type_lookup.lookup_type other.name
      return super unless generic_class == self.generic_class

      generic_class = generic_class as TupleType
      return nil unless other.type_vars.size == tuple_types.size

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
      return nil unless generic_module.type_vars.size == @module.type_vars.size

      @module.type_vars.zip(other.type_vars) do |module_type_var, other_type_var|
        if m = @mapping[module_type_var]?
          t = TypeLookup.lookup(@including_class, m)
          restricted = t.restrict other_type_var, context
          return nil unless restricted

          if other_type_var.is_a?(Path) && other_type_var.names.size == 1
            context.set_free_var(other_type_var.names.first, restricted)
          end
        end
      end

      self
    end
  end

  class InheritedGenericClass
    def is_restriction_of?(other : GenericClassInstanceType, owner)
      return nil unless extended_class == other.generic_class

      mapping.each do |name, node|
        typevar_type = TypeLookup.lookup(extending_class, node)
        other_type = other.type_vars[name].type.devirtualize
        unless typevar_type.implements?(other_type)
          return nil
        end
      end

      self
    end

    def is_restriction_of?(other : Type, owner)
      @extended_class.is_restriction_of?(other, owner)
    end

    def restrict(other : Generic, context)
      generic_class = context.type_lookup.lookup_type other.name
      return nil unless generic_class == @extended_class

      generic_class = generic_class as GenericClassType
      return nil unless generic_class.type_vars.size == type_vars.size

      type_vars.zip(other.type_vars) do |class_type_var, other_type_var|
        if m = @mapping[class_type_var]?
          t = TypeLookup.lookup(extending_class, m)
          restricted = t.restrict other_type_var, context
          return nil unless restricted && t == restricted

          if other_type_var.is_a?(Path) && other_type_var.names.size == 1
            context.set_free_var(other_type_var.names.first, restricted)
          end
        end
      end

      self
    end
  end

  class VirtualType
    def is_restriction_of?(other : Type, owner)
      other = other.base_type if other.is_a?(VirtualType)
      base_type.is_subclass_of?(other) || other.is_subclass_of?(base_type)
    end

    def restrict(other : Type, context)
      if self == other
        self
      elsif other.is_a?(UnionType)
        types = other.union_types.compact_map do |t|
          restrict(t, context) as Type?
        end
        program.type_merge types
      elsif other.is_a?(VirtualType)
        result = base_type.restrict(other.base_type, context) || other.base_type.restrict(base_type, context)
        result ? result.virtual_type : nil
      elsif other.is_subclass_of?(self.base_type)
        other.virtual_type
      elsif self.base_type.is_subclass_of?(other)
        self
      elsif other.module?
        if base_type.implements?(other)
          self
        else
          types = base_type.subclasses.compact_map do |subclass|
            subclass.virtual_type.restrict(other, context) as Type?
          end
          program.type_merge_union_of types
        end
      else
        nil
      end
    end

    def restrict(other : Generic, context)
      types = base_type.subclasses.compact_map do |subclass|
        subclass.virtual_type.restrict(other, context) as Type?
      end
      program.type_merge_union_of types
    end
  end

  class NonGenericModuleType
    def restrict(other, context)
      including_types.try &.restrict(other, context)
    end
  end

  class AliasType
    def is_restriction_of?(other, owner)
      return true if self == other

      remove_alias.is_restriction_of?(other, owner)
    end

    def restrict(other : Path, context)
      other_type = context.type_lookup.lookup_type other
      if other_type
        if other_type == self
          return self
        end
      else
        single_name = other.names.size == 1
        if single_name
          if Parser.free_var_name?(other.names.first)
            return context.set_free_var(other.names.first, self)
          else
            other.raise "undefined constant #{other}"
          end
        end
      end

      remove_alias.restrict(other, context)
    end

    def restrict(other, context)
      return self if self == other

      remove_alias.restrict(other, context)
    end
  end

  class MetaclassType
    def restrict(other : Metaclass, context)
      restricted = instance_type.restrict(other.name, context)
      restricted ? self : nil
    end

    def restrict(other : VirtualMetaclassType, context)
      restricted = instance_type.restrict(other.instance_type.base_type, context)
      restricted ? self : nil
    end
  end

  class GenericClassInstanceMetaclassType
    def restrict(other : Metaclass, context)
      restricted = instance_type.restrict(other.name, context)
      restricted ? self : nil
    end
  end

  class FunInstanceType
    def restrict(other : Fun, context)
      inputs = other.inputs
      inputs_len = inputs ? inputs.size : 0
      output = other.output

      return nil if fun_types.size != inputs_len + 1

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

      return nil unless other.type_vars.size == fun_types.size

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
      other_arg_types = other.arg_types
      other_return_type = other.return_type

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
      return nil if arg_types.size != other_arg_types.size

      arg_types.zip(other_arg_types) do |arg_type, other_arg_type|
        return false unless arg_type == other_arg_type
      end

      true
    end
  end
end
