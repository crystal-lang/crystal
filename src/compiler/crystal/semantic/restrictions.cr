require "../syntax/ast"
require "../types"

# Here is the logic for deciding two things:
#
# 1. Whether a method should come before another one
#    when considering overloads.
#    This is what `restriction_of?` is for.
# 2. What's the resulting type of filtering a type
#    by a restriction.
#    This is what `restrict` is for.
#
# If `a.restriction_of?(b)` is true, it means that
# `a` should come before `b` when considering restrictions.
# This applies almost always to AST nodes, which are
# sometimes resolved to see if a type inherits another
# one (and so it should be considered before that type),
# but can apply to types when arguments have a fixed
# type (mostly for primitive methods, though we should
# get rid of this to simplify things).
# A similar logic applies to a `Def`, where this logic
# is applied for each of the arguments, though here
# the number of arguments, splat index and other factors
# are considered.
# If `a.restriction_of?(b) == true` and `b.restriction_of?(a) == true`,
# for `a` and `b` being `Def`s, then it means `a` and `b` are equivalent,
# and so when adding `b` to a types methods it will replace `a`.
#
# The method `restrict` is different in that the return
# value is not a boolean, but a type, and computing it
# might be a bit more expensive. For example when restricting
# `Int32 | String` against `Int32`, the result is `Int32`.

module Crystal
  record RestrictionsContext, owner : Type,
    self_def : DefWithMetadata? = nil,
    other_def : DefWithMetadata? = nil

  class ASTNode
    def restriction_of?(other : Underscore, ctx)
      true
    end

    def restriction_of?(other : ASTNode, ctx)
      self == other
    end

    def restriction_of?(other : Type, ctx)
      false
    end

    def restriction_of?(other, ctx)
      raise "BUG: called #{self}.restriction_of?(#{other})"
    end
  end

  class Self
    def restriction_of?(type : Type, ctx)
      ctx.owner.restriction_of?(type, ctx)
    end

    def restriction_of?(type : Self, ctx)
      true
    end

    def restriction_of?(type : ASTNode, ctx)
      false
    end
  end

  struct DefWithMetadata
    def restriction_of?(other : DefWithMetadata, ctx)
      # This is how multiple defs are sorted by 'restrictions' (?)

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

          return false unless self_type.restriction_of?(other_type, ctx)
        end
      end

      if self_splat_index && other_splat_index
        if self_splat_index == other_splat_index
          self_arg = self.def.args[self_splat_index]
          other_arg = other.def.args[other_splat_index]
          self_restriction = self_arg.restriction
          other_restriction = other_arg.restriction

          if self_restriction && other_restriction
            # If both splat have restrictions, check which one is stricter
            return false unless self_restriction.restriction_of?(other_restriction, ctx)
          elsif self_restriction
            # If only self has a restriction, it's stricter than the other
            return true
          elsif other_restriction
            # If only the other has a restriction, it's stricter than self
            return false
          end
        elsif self_splat_index < other_splat_index
          return false
        else
          return true
        end
      end

      # Check required named arguments
      self_named_args = self.required_named_arguments
      other_named_args = other.required_named_arguments

      # If both have named args we must restrict name by name
      if self_named_args && other_named_args
        self_names = self_named_args.map(&.external_name)
        other_names = other_named_args.map(&.external_name)

        # If the names of the required named args are different, these are different overloads
        return false if self_names != other_names

        # They are the same, so we apply usual restriction checking on the args
        self_named_args.zip(other_named_args) do |self_arg, other_arg|
          self_restriction = self_arg.restriction
          other_restriction = other_arg.restriction
          return false if self_restriction == nil && other_restriction != nil

          if self_restriction && other_restriction
            return false unless self_restriction.restriction_of?(other_restriction, ctx)
          end
        end

        return true
      end

      # If one has required named args and the other doesn't, none is stricter than the other
      if (self_named_args || other_named_args)
        return false
      end

      self_double_splat_restriction = self.def.double_splat.try &.restriction
      other_double_splat_restriction = other.def.double_splat.try &.restriction

      # If both double splat have restrictions, check which one is stricter
      if self_double_splat_restriction && other_double_splat_restriction
        return false unless self_double_splat_restriction.restriction_of?(other_double_splat_restriction, ctx)
      elsif self_double_splat_restriction
        # If only self has a restriction, it's stricter than the other
        return true
      elsif other_double_splat_restriction
        # If only the other has a restriction, it's stricter than self
        return false
      end

      true
    end

    def required_named_arguments
      if (splat_index = self.def.splat_index) && splat_index != self.def.args.size - 1
        self.def.args[splat_index + 1..-1].select { |arg| !arg.default_value }.sort_by &.external_name
      else
        nil
      end
    end
  end

  class Macro
    def overrides?(other : Macro)
      # If they have different number of arguments, splat index or presence of
      # double splat, no override.
      if args.size != other.args.size ||
         splat_index != other.splat_index ||
         !!double_splat != !!other.double_splat
        return false
      end

      self_named_args = self.required_named_arguments
      other_named_args = other.required_named_arguments

      # If both don't have named arguments, override.
      return true if !self_named_args && !other_named_args

      # If one has required named args and the other doesn't, no override.
      return false unless self_named_args && other_named_args

      self_names = self_named_args.map(&.external_name)
      other_names = other_named_args.map(&.external_name)

      # If different named arguments names, no override.
      return false unless self_names == other_names

      true
    end

    def required_named_arguments
      if (splat_index = self.splat_index) && splat_index != args.size - 1
        args[splat_index + 1..-1].select { |arg| !arg.default_value }.sort_by &.external_name
      else
        nil
      end
    end
  end

  class Path
    def restriction_of?(other : Path, ctx)
      return true if self == other

      self_type = ctx.owner.lookup_path(self)
      if self_type
        other_type = ctx.owner.lookup_path(other)
        if other_type
          return self_type.restriction_of?(other_type, ctx)
        else
          return true
        end
      end

      false
    end

    def restriction_of?(other : Union, ctx)
      # `true` if this type is a restriction of any type in the union
      other.types.any? { |o| self.restriction_of?(o, ctx) }
    end

    def restriction_of?(other : Generic, ctx)
      self_type = ctx.owner.lookup_path(self)
      if self_type
        other_type = ctx.owner.lookup_type?(other)
        if other_type
          return self_type.restriction_of?(other_type, ctx)
        end
      end

      false
    end

    def restriction_of?(other, ctx)
      false
    end
  end

  class Union
    def restriction_of?(other : Path, ctx)
      # For a union to be considered before a path,
      # all types in the union must be considered before
      # that path.
      # For example when using all subtypes of a parent type.
      types.all? &.restriction_of?(other, ctx)
    end
  end

  class Generic
    def restriction_of?(other : Path, ctx)
      self_type = ctx.owner.lookup_type?(self)
      if self_type
        other_type = ctx.owner.lookup_path(other)
        if other_type
          return self_type.restriction_of?(other_type, ctx)
        end
      end

      false
    end

    def restriction_of?(other : Generic, ctx)
      return true if self == other
      return false unless name == other.name && type_vars.size == other.type_vars.size

      type_vars.zip(other.type_vars) do |type_var, other_type_var|
        return false unless type_var.restriction_of?(other_type_var, ctx)
      end

      true
    end
  end

  class GenericClassType
    def restriction_of?(other : GenericClassInstanceType, ctx)
      # ```
      # def foo(param : Array)
      # end
      #
      # def foo(param : Array(Int32))
      # end
      # ```
      #
      # Here, self is `Array`, other is `Array(Int32)`

      # Even when the underlying generic type is the same,
      # `SomeGeneric` is never a restriction of `SomeGeneric(X)`
      false
    end
  end

  class GenericClassInstanceType
    def restriction_of?(other : GenericClassType, ctx)
      # ```
      # def foo(param : Array(Int32))
      # end
      #
      # def foo(param : Array)
      # end
      # ```
      #
      # Here, self is `Array(Int32)`, other is `Array`

      # When the underlying generic type is the same:
      # `SomeGeneric(X)` is always a restriction of `SomeGeneric`
      self.generic_type == other
    end
  end

  class Metaclass
    def restriction_of?(other : Metaclass, ctx)
      self_type = ctx.owner.lookup_type?(self)
      other_type = ctx.owner.lookup_type?(other)
      if self_type && other_type
        self_type.restriction_of?(other_type, ctx)
      elsif self_type
        # `other` cannot resolve to a type, it's probably a free variable like:
        #
        # ```
        # def foo(param : T.class) forall T
        # end
        #
        # def foo(param : Int32.class)
        # end
        # ```
        true
      else
        false
      end
    end
  end

  class Type
    def restrict(other : Nil, match_ctx)
      self
    end

    def restrict(other : Type, match_ctx)
      if self == other
        return self
      end

      # Allow Nil to match Void (useful for `Pointer(Void)#value=`)
      if nil_type? && other.void?
        return self
      end

      restriction_ctx = RestrictionsContext.new owner: match_ctx.instantiated_type
      if parents.try &.any? &.restriction_of?(other, restriction_ctx)
        return self
      end

      nil
    end

    def restrict(other : AliasType, match_ctx)
      if self == other
        self
      else
        restrict(other.remove_alias, match_ctx)
      end
    end

    def restrict(other : Self, match_ctx)
      restrict(match_ctx.instantiated_type.instance_type, match_ctx)
    end

    def restrict(other : TypeOf, match_ctx)
      other.raise "can't use typeof in type restrictions"
    end

    def restrict(other : UnionType, match_ctx)
      restricted = nil

      other.union_types.each do |union_type|
        # Apply the restriction logic on each union type, even if we already
        # have a match, so that we can detect ambiguous calls between of
        # literal types against aliases that resolve to union types.
        restriction = restrict(union_type, match_ctx)
        restricted ||= restriction
      end

      restricted ? self : nil
    end

    def restrict(other : VirtualType, match_ctx)
      implements?(other.base_type) ? self : nil
    end

    def restrict(other : Union, match_ctx)
      types = other.types.compact_map do |ident|
        restrict(ident, match_ctx).as(Type?)
      end
      types.size > 0 ? program.type_merge_union_of(types) : nil
    end

    def restrict(other : Path, match_ctx)
      single_name = other.names.size == 1
      if single_name
        first_name = other.names.first
        if match_ctx.has_def_free_var?(first_name)
          return match_ctx.set_free_var(first_name, self)
        end
      end

      if single_name
        owner = match_ctx.instantiated_type

        # Special case: if we have an *uninstantiated* generic type like Foo(X)
        # and a restriction X, it matches, and we add X to the free vars.
        if owner.is_a?(GenericType)
          first_name = other.names.first
          if owner.type_vars.includes?(first_name)
            match_ctx.set_free_var(first_name, self)
            return self
          end
        end

        ident_type = match_ctx.get_free_var(other.names.first)
      end

      had_ident_type = !!ident_type
      ident_type ||= match_ctx.defining_type.lookup_path other

      if ident_type
        if ident_type.is_a?(Const)
          other.raise "#{ident_type} is not a type, it's a constant"
        end

        return restrict ident_type, match_ctx
      end

      if single_name
        first_name = other.names.first
        if match_ctx.defining_type.type_var?(first_name)
          return match_ctx.set_free_var(first_name, self)
        end
      end

      if had_ident_type
        other.raise "undefined constant #{other}"
      else
        other.raise_undefined_constant(match_ctx.defining_type)
      end
    end

    def restrict(other : Generic, match_ctx)
      # Special case: consider `Union(X, Y, ...)` the same as `X | Y | ...`
      generic_type = get_generic_type(other, match_ctx)
      if generic_type.is_a?(GenericUnionType)
        return restrict(Union.new(other.type_vars), match_ctx)
      end

      parents.try &.each do |parent|
        next if parent.is_a?(NonGenericModuleType)

        restricted = parent.restrict other, match_ctx
        return self if restricted
      end

      nil
    end

    def restrict(other : Metaclass, match_ctx)
      nil
    end

    def restrict(other : ProcNotation, match_ctx)
      nil
    end

    def restrict(other : Underscore, match_ctx)
      self
    end

    def restrict(other : Arg, match_ctx)
      restrict (other.type? || other.restriction), match_ctx
    end

    def restrict(other : NumberLiteral, match_ctx)
      nil
    end

    def restrict(other : Splat, match_ctx)
      nil
    end

    def restrict(other : ASTNode, match_ctx)
      raise "BUG: unsupported restriction: #{self} vs. #{other}"
    end

    def restriction_of?(other : UnionType, ctx)
      other.union_types.any? { |subtype| restriction_of?(subtype, ctx) }
    end

    def restriction_of?(other : VirtualType, ctx)
      implements? other.base_type
    end

    def restriction_of?(other : Type, ctx)
      if self == other
        return true
      end

      parents.try &.any? &.restriction_of?(other, ctx)
    end

    def restriction_of?(other : AliasType, ctx)
      if self == other
        true
      else
        restriction_of?(other.remove_alias, ctx)
      end
    end

    def restriction_of?(other : ASTNode, ctx)
      raise "BUG: called #{self}.restriction_of?(#{other})"
    end

    def compatible_with?(type)
      self == type
    end
  end

  class UnionType
    def restriction_of?(type, ctx)
      self == type || union_types.any? &.restriction_of?(type, ctx)
    end

    def restrict(other : Union, match_ctx)
      types = [] of Type
      discarded = [] of Type
      other.types.each do |other_type|
        self.union_types.each do |type|
          next if discarded.includes?(type)

          restricted = type.restrict(other_type, match_ctx)
          if restricted
            types << restricted
            discarded << type
          end
        end
      end

      program.type_merge_union_of(types)
    end

    def restrict(other : Type, match_ctx)
      restrict_type_or_fun_or_generic other, match_ctx
    end

    def restrict(other : ProcNotation, match_ctx)
      restrict_type_or_fun_or_generic other, match_ctx
    end

    def restrict(other : Generic, match_ctx)
      restrict_type_or_fun_or_generic other, match_ctx
    end

    def restrict(other : Metaclass, match_ctx)
      restrict_type_or_fun_or_generic other, match_ctx
    end

    def restrict_type_or_fun_or_generic(other, match_ctx)
      types = union_types.compact_map do |type|
        type.restrict(other, match_ctx).as(Type?)
      end
      program.type_merge_union_of(types)
    end
  end

  class GenericInstanceType
    def restriction_of?(other : GenericType, ctx)
      return true if generic_type == other
      super
    end

    def restriction_of?(other : GenericInstanceType, ctx)
      return super unless generic_type == other.generic_type

      type_vars.each do |name, type_var|
        other_type_var = other.type_vars[name]
        if type_var.is_a?(Var) && other_type_var.is_a?(Var)
          restricted = type_var.type.implements?(other_type_var.type)
          return nil unless restricted
        else
          return nil unless type_var == other_type_var
        end
      end

      true
    end

    def restrict(other : GenericType, contet)
      generic_type == other ? self : super
    end

    def restrict(other : Generic, match_ctx)
      generic_type = get_generic_type(other, match_ctx)
      generic_type = generic_type.remove_alias if generic_type.is_a? AliasType
      return super unless generic_type == self.generic_type

      generic_type = generic_type.as(GenericType)

      if other.named_args
        unless generic_type.is_a?(NamedTupleType)
          other.raise "can only instantiate NamedTuple with named arguments"
        end
        # We match named tuples in NamedTupleInstanceType
        return nil
      end

      # Consider the case of a splat in the type vars
      splat_index = other.type_vars.index &.is_a?(Splat)
      if splat_index
        types = Array(Type).new(type_vars.size)
        i = 0
        type_vars.each_value do |var|
          return nil unless var.is_a?(Var)

          var_type = var.type
          if i == self.splat_index
            types.concat(var_type.as(TupleInstanceType).tuple_types)
          else
            types << var_type
          end
          i += 1
        end

        i = 0
        found_splat = false
        other.type_vars.each do |type_var|
          if type_var.is_a?(Splat)
            type_var.raise "can't specify more than one splat in restriction" if found_splat
            found_splat = true

            count = types.size - (other.type_vars.size - 1)
            return nil unless count >= 0

            arg_types = types[i, count]
            arg_types_tuple = match_ctx.instantiated_type.program.tuple_of(arg_types)

            restricted = arg_types_tuple.restrict(type_var.exp, match_ctx)
            return nil unless restricted == arg_types_tuple

            i += count
          else
            arg_type = types[i]
            restricted = arg_type.restrict(type_var, match_ctx)
            return unless restricted == arg_type

            i += 1
          end
        end

        return self
      end

      if generic_type.type_vars.size != other.type_vars.size
        other.wrong_number_of "type vars", generic_type, other.type_vars.size, generic_type.type_vars.size
      end

      i = 0
      type_vars.each do |name, type_var|
        other_type_var = other.type_vars[i]
        restricted = restrict_type_var(type_var, other_type_var, match_ctx)
        return nil unless restricted
        i += 1
      end

      self
    end

    def restrict(other : GenericInstanceType, match_ctx)
      return super unless generic_type == other.generic_type

      type_vars.each do |name, type_var|
        other_type_var = other.type_vars[name]
        restricted = restrict_type_var(type_var, other_type_var, match_ctx)
        return super unless restricted
      end

      self
    end

    def restrict_type_var(type_var, other_type_var, match_ctx)
      if type_var.is_a?(NumberLiteral)
        case other_type_var
        when NumberLiteral
          if type_var == other_type_var
            return type_var
          end
        when Path
          if other_type_var.names.size == 1
            name = other_type_var.names.first

            # If the free variable is already set to another
            # number, there's no match
            existing = match_ctx.get_free_var(name)
            if existing && existing != type_var
              return nil
            end

            match_ctx.set_free_var(name, type_var)
            return type_var
          end
        end
      else
        type_var = type_var.type? || type_var
      end

      unless other_type_var.is_a?(NumberLiteral)
        other_type_var = other_type_var.type? || other_type_var
      end

      if type_var.is_a?(ASTNode)
        restriction_ctx = RestrictionsContext.new owner: match_ctx.instantiated_type
        type_var.restriction_of?(other_type_var, restriction_ctx)
      elsif match_ctx.strict?
        type_var == other_type_var
      else
        # To prevent infinite recursion, it checks equality between
        # `type_var` and `other_type_var` directly before try to restrict
        # `type_var` by `other_type_var`.
        type_var == other_type_var || type_var.restrict(other_type_var, match_ctx) == type_var
      end
    end
  end

  class TupleInstanceType
    def restriction_of?(other : TupleInstanceType, ctx)
      return true if self == other || self.implements?(other)

      false
    end

    def restrict(other : Generic, match_ctx)
      generic_type = get_generic_type(other, match_ctx)
      return super unless generic_type == self.generic_type

      generic_type = generic_type.as(TupleType)

      # Consider the case of a splat in the type vars
      splat_index = other.type_vars.index &.is_a?(Splat)
      if splat_index
        found_splat = false
        i = 0
        other.type_vars.each do |type_var|
          if type_var.is_a?(Splat)
            type_var.raise "can't specify more than one splat in restriction" if found_splat
            found_splat = true

            count = tuple_types.size - (other.type_vars.size - 1)
            return nil unless count >= 0

            arg_types = tuple_types[i, count]
            arg_types_tuple = match_ctx.instantiated_type.program.tuple_of(arg_types)

            restricted = arg_types_tuple.restrict(type_var.exp, match_ctx)
            return nil unless restricted == arg_types_tuple

            i += count
          else
            arg_type = tuple_types[i]
            restricted = arg_type.restrict(type_var, match_ctx)
            return unless restricted == arg_type

            i += 1
          end
        end

        return self
      else
        return nil unless other.type_vars.size == tuple_types.size

        tuple_types.zip(other.type_vars) do |tuple_type, type_var|
          restricted = tuple_type.restrict(type_var, match_ctx)
          return nil unless restricted == tuple_type
        end
      end

      self
    end

    def restrict(other : TupleInstanceType, match_ctx)
      self.implements?(other) ? self : nil
    end
  end

  class NamedTupleInstanceType
    def restriction_of?(other : NamedTupleInstanceType, ctx)
      return true if self == other || self.implements?(other)

      false
    end

    def restrict(other : Generic, match_ctx)
      generic_type = get_generic_type(other, match_ctx)
      return super unless generic_type == self.generic_type

      other_named_args = other.named_args
      unless other_named_args
        other.raise "can only instantiate NamedTuple with named arguments"
      end

      # Check that the names are the same
      other_names = other_named_args.map(&.name).sort!
      self_names = self.entries.map(&.name).sort!

      return nil unless self_names == other_names

      # Now match name by name
      other_named_args.each do |named_arg|
        self_type = self.name_type(named_arg.name)
        other_type = named_arg.value

        restricted = self_type.restrict(other_type, match_ctx)
        return nil unless restricted
      end

      self
    end

    def restrict(other : NamedTupleInstanceType, match_ctx)
      self.implements?(other) ? self : nil
    end
  end

  class VirtualType
    def restriction_of?(other : Type, ctx)
      other = other.base_type if other.is_a?(VirtualType)
      base_type.implements?(other) || other.implements?(base_type)
    end

    def restrict(other : Type, match_ctx)
      other = other.remove_alias
      base_type = self.base_type

      if self == other
        self
      elsif other.is_a?(UnionType)
        types = other.union_types.compact_map do |t|
          restrict(t, match_ctx).as(Type?)
        end
        program.type_merge types
      elsif other.is_a?(VirtualType)
        result = base_type.restrict(other.base_type, match_ctx) || other.base_type.restrict(base_type, match_ctx)
        result ? result.virtual_type : nil
      elsif other.implements?(base_type)
        other.virtual_type
      elsif base_type.implements?(other)
        self
      elsif other.module?
        if base_type.implements?(other)
          self
        else
          types = base_type.subclasses.compact_map do |subclass|
            subclass.virtual_type.restrict(other, match_ctx).as(Type?)
          end
          program.type_merge_union_of types
        end
      elsif base_type.is_a?(GenericInstanceType) && other.is_a?(GenericType)
        # Consider the case of Foo(Int32) vs. Bar(T), with Bar(T) < Foo(T):
        # we want to return Bar(Int32), so we search in Bar's generic instantiations
        other.generic_types.values.each do |instance|
          if instance.implements?(base_type)
            return instance
          end
        end
        nil
      else
        nil
      end
    end

    def restrict(other : Generic, match_ctx)
      # Restrict first against the base type
      restricted = base_type.restrict(other, match_ctx)
      if restricted
        return restricted.virtual_type
      end

      types = base_type.subclasses.compact_map do |subclass|
        subclass.virtual_type.restrict(other, match_ctx).as(Type?)
      end
      program.type_merge_union_of types
    end
  end

  class VirtualMetaclassType
    def restrict(other : Metaclass, match_ctx)
      instance_type.restrict(other.name, match_ctx).try &.metaclass
    end
  end

  class NonGenericModuleType
    def restrict(other, match_ctx)
      super || including_types.try(&.restrict(other, match_ctx))
    end
  end

  class AliasType
    def restriction_of?(other, ctx)
      return true if self == other

      remove_alias.restriction_of?(other, ctx)
    end

    def restrict(other : Path, match_ctx)
      single_name = other.names.size == 1
      if single_name
        first_name = other.names.first
        if match_ctx.has_def_free_var?(first_name)
          return match_ctx.set_free_var(first_name, self)
        end
      end

      other_type = match_ctx.defining_type.lookup_path other
      if other_type
        if other_type == self
          return self
        end
      else
        single_name = other.names.size == 1
        if single_name
          first_name = other.names.first
          if match_ctx.defining_type.type_var?(first_name)
            return match_ctx.set_free_var(first_name, self)
          else
            other.raise_undefined_constant(match_ctx.defining_type)
          end
        end
      end

      remove_alias.restrict(other, match_ctx)
    end

    def restrict(other : AliasType, match_ctx)
      return self if self == other

      if !self.simple? && !other.simple?
        return nil
      end

      remove_alias.restrict(other, match_ctx)
    end

    def restrict(other, match_ctx)
      return self if self == other

      remove_alias.restrict(other, match_ctx)
    end
  end

  class TypeDefType
    def restrict(other : UnionType, match_ctx)
      super
    end

    def restrict(other : Type, match_ctx)
      return self if self == other

      restricted = typedef.restrict(other, match_ctx)
      if restricted == typedef
        return self
      elsif restricted.is_a?(UnionType)
        program.type_merge(restricted.union_types.map { |t| t == typedef ? self : t })
      else
        restricted
      end
    end
  end

  class MetaclassType
    def restrict(other : Metaclass, match_ctx)
      restricted = instance_type.restrict(other.name, match_ctx)
      instance_type == restricted ? self : nil
    end

    def restrict(other : VirtualMetaclassType, match_ctx)
      # A module class can't be restricted into a class
      return nil if instance_type.module?

      restricted = instance_type.restrict(other.instance_type.base_type, match_ctx)
      restricted ? self : nil
    end

    def restriction_of?(other : VirtualMetaclassType, ctx)
      restriction_of?(other.base_type.metaclass, ctx)
    end
  end

  class GenericClassInstanceMetaclassType
    def restrict(other : Metaclass, match_ctx)
      restricted = instance_type.restrict(other.name, match_ctx)
      instance_type == restricted ? self : nil
    end

    def restrict(other : MetaclassType, match_ctx)
      return self if instance_type.generic_type.metaclass == other

      restricted = instance_type.restrict(other.instance_type, match_ctx)
      restricted ? self : nil
    end
  end

  class GenericModuleInstanceMetaclassType
    def restrict(other : Metaclass, match_ctx)
      restricted = instance_type.restrict(other.name, match_ctx)
      instance_type == restricted ? self : nil
    end

    def restrict(other : MetaclassType, match_ctx)
      return self if instance_type.generic_type.metaclass == other

      restricted = instance_type.restrict(other.instance_type, match_ctx)
      restricted ? self : nil
    end
  end

  class ProcInstanceType
    def restrict(other : ProcNotation, match_ctx)
      inputs = other.inputs
      inputs_size = inputs ? inputs.size : 0
      output = other.output

      # Consider the case of a splat in the type vars
      if inputs && (splat_index = inputs.index &.is_a?(Splat))
        i = 0
        inputs.each do |input|
          if input.is_a?(Splat)
            count = arg_types.size - (inputs.size - 1)
            return nil unless count >= 0

            input_arg_types = arg_types[i, count]
            input_arg_types_tuple = match_ctx.instantiated_type.program.tuple_of(input_arg_types)

            restricted = input_arg_types_tuple.restrict(input.exp, match_ctx)
            return nil unless restricted == input_arg_types_tuple

            i += count
          else
            arg_type = arg_types[i]
            restricted = arg_type.restrict(input, match_ctx)
            return unless restricted == arg_type

            i += 1
          end
        end
      else
        return nil if arg_types.size != inputs_size

        if inputs
          inputs.zip(arg_types) do |input, my_input|
            restricted = my_input.restrict(input, match_ctx)
            return nil unless restricted == my_input
          end
        end
      end

      if output
        my_output = self.return_type
        if my_output.no_return?
          # Ok, NoReturn can be "cast" to anything
        else
          restricted = my_output.restrict(output, match_ctx)
          return nil unless restricted == my_output
        end

        self
      else
        program.proc_of(arg_types + [program.void])
      end
    end

    def restrict(other : ProcInstanceType, match_ctx)
      compatible_with?(other) ? other : nil
    end

    def restrict(other : Generic, match_ctx)
      generic_type = get_generic_type(other, match_ctx)
      return super unless generic_type.is_a?(ProcType)

      # Consider the case of a splat in the type vars
      splat_index = other.type_vars.index &.is_a?(Splat)
      if splat_index
        proc_types = arg_types + [return_type]

        i = 0
        other.type_vars.each do |type_var|
          if type_var.is_a?(Splat)
            count = proc_types.size - (other.type_vars.size - 1)
            return nil unless count >= 0

            arg_types = proc_types[i, count]
            arg_types_tuple = match_ctx.instantiated_type.program.tuple_of(arg_types)

            restricted = arg_types_tuple.restrict(type_var.exp, match_ctx)
            return nil unless restricted == arg_types_tuple

            i += count
          else
            arg_type = proc_types[i]
            restricted = arg_type.restrict(type_var, match_ctx)
            return unless restricted == arg_type

            i += 1
          end
        end

        return self
      end

      unless other.type_vars.size == arg_types.size + 1
        return nil
      end

      other.type_vars.each_with_index do |other_type_var, i|
        proc_type = arg_types[i]? || return_type
        restricted = proc_type.restrict other_type_var, match_ctx
        return nil unless restricted == proc_type
      end

      self
    end

    def compatible_with?(other : ProcInstanceType)
      if return_type == other.return_type
        # Ok
      elsif other.return_type.nil_type?
        # Ok, can cast fun to void
      elsif return_type.no_return?
        # Ok, NoReturn can be "cast" to anything
      else
        return false
      end

      # Disallow casting a function to another one accepting different argument count
      return nil if arg_types.size != other.arg_types.size

      arg_types.zip(other.arg_types) do |arg_type, other_arg_type|
        return false unless arg_type == other_arg_type
      end

      true
    end
  end

  class NumberLiteralType
    def restrict(other, match_ctx)
      if other.is_a?(IntegerType) || other.is_a?(FloatType)
        # Check for an exact match, which can't produce an ambiguous call
        if literal.type == other
          set_exact_match(other)
          other
        elsif !exact_match? && literal.can_be_autocast_to?(other)
          add_match(other)
          other
        else
          literal.type.restrict(other, match_ctx)
        end
      else
        type = super(other, match_ctx) ||
               literal.type.restrict(other, match_ctx)
        if type == self
          type = @match || literal.type
        end
        type
      end
    end
  end

  class SymbolLiteralType
    def restrict(other, match_ctx)
      case other
      when SymbolType
        set_exact_match(other)
        other
      when EnumType
        if !exact_match? && other.find_member(literal.value)
          add_match(other)
          other
        else
          literal.type.restrict(other, match_ctx)
        end
      else
        type = super(other, match_ctx) ||
               literal.type.restrict(other, match_ctx)
        if type == self
          type = @match || literal.type
        end
        type
      end
    end
  end
end

private def get_generic_type(node, match_ctx)
  name = node.name
  if name.is_a?(Crystal::Path)
    match_ctx.defining_type.lookup_path name
  else
    name.type
  end
end
