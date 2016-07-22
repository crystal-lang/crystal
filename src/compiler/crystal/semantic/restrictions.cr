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
  class ASTNode
    def restriction_of?(other : Underscore, owner)
      true
    end

    def restriction_of?(other : ASTNode, owner)
      self == other
    end

    def restriction_of?(other : Type, owner)
      false
    end

    def restriction_of?(other, owner)
      raise "Bug: called #{self}.restriction_of?(#{other})"
    end
  end

  class Self
    def restriction_of?(type : Type, owner)
      owner.restriction_of?(type, owner)
    end

    def restriction_of?(type : Self, owner)
      true
    end

    def restriction_of?(type : ASTNode, owner)
      false
    end
  end

  struct DefWithMetadata
    def restriction_of?(other : DefWithMetadata, owner)
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

          return false unless self_type.restriction_of?(other_type, owner)
        end
      end

      if self_splat_index && other_splat_index
        if self_splat_index == other_splat_index
          self_arg = self.def.args[self_splat_index]
          other_arg = other.def.args[other_splat_index]

          if (self_restriction = self_arg.restriction) && (other_restriction = other_arg.restriction)
            return false unless self_restriction.restriction_of?(other_restriction, owner)
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
            return false unless self_restriction.restriction_of?(other_restriction, owner)
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

      if self_double_splat_restriction && other_double_splat_restriction
        return false unless self_double_splat_restriction.restriction_of?(other_double_splat_restriction, owner)
      elsif self_double_splat_restriction
        true
      elsif other_double_splat_restriction
        false
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
      # For now we consider that a macro overrides another macro
      # if it has the same number of arguments, splat index and
      # named arguments.
      args.size == other.args.size &&
        splat_index == other.splat_index &&
        !!double_splat == !!other.double_splat
    end
  end

  class Path
    def restriction_of?(other : Path, owner)
      return true if self == other

      self_type = owner.lookup_type(self)
      if self_type
        other_type = owner.lookup_type(other)
        if other_type
          return self_type.restriction_of?(other_type, owner)
        else
          return true
        end
      end

      false
    end

    def restriction_of?(other : Union, owner)
      # `true` if this type is a restriction of any type in the union
      other.types.any? { |o| self.restriction_of?(o, owner) }
    end

    def restriction_of?(other, owner)
      false
    end
  end

  class Union
    def restriction_of?(other : Path, owner)
      # For a union to be considered before a path,
      # all types in the union must be considered before
      # that path.
      # For example when using all subtypes of a parent type.
      types.all? &.restriction_of?(other, owner)
    end
  end

  class Generic
    def restriction_of?(other : Generic, owner)
      return true if self == other
      return false unless name == other.name && type_vars.size == other.type_vars.size

      type_vars.zip(other.type_vars) do |type_var, other_type_var|
        return false unless type_var.restriction_of?(other_type_var, owner)
      end

      true
    end
  end

  class Metaclass
    def restriction_of?(other : Metaclass, owner)
      self_type = TypeLookup.lookup?(owner, self)
      other_type = TypeLookup.lookup?(owner, other)
      if self_type && other_type
        self_type.restriction_of?(other_type, owner)
      else
        self == other
      end
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

      # Allow Nil to match Void (useful for `Pointer(Void)#value=`)
      if nil_type? && other.void?
        return self
      end

      if parents.try &.any? &.restriction_of?(other, context.owner)
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
      restricted = other.union_types.any? { |union_type| restriction_of?(union_type, context.owner) }
      restricted ? self : nil
    end

    def restrict(other : VirtualType, context)
      subclass_of?(other.base_type) ? self : nil
    end

    def restrict(other : Union, context)
      types = other.types.compact_map do |ident|
        restrict(ident, context).as(Type?)
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
      # Special case: consider `Union(X, Y, ...)` the same as `X | Y | ...`
      generic_class = context.type_lookup.lookup_type other.name
      if generic_class.is_a?(GenericUnionType)
        return restrict(Union.new(other.type_vars), context)
      end

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

    def restrict(other : ProcNotation, context)
      nil
    end

    def restrict(other : Underscore, context)
      self
    end

    def restrict(other : ASTNode, context)
      raise "Bug: unsupported restriction: #{self} vs. #{other}"
    end

    def restriction_of?(other : UnionType, owner)
      other.union_types.any? { |subtype| restriction_of?(subtype, owner) }
    end

    def restriction_of?(other : VirtualType, owner)
      subclass_of? other.base_type
    end

    def restriction_of?(other : Type, owner)
      if self == other
        return true
      end

      parents.try &.any? &.restriction_of?(other, owner)
    end

    def restriction_of?(other : AliasType, owner)
      if self == other
        true
      else
        restriction_of?(other.remove_alias, owner)
      end
    end

    def restriction_of?(other : ASTNode, owner)
      raise "Bug: called #{self}.restriction_of?(#{other})"
    end

    def compatible_with?(type)
      self == type
    end
  end

  class UnionType
    def restriction_of?(type, owner)
      self == type || union_types.any? &.restriction_of?(type, owner)
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

    def restrict(other : ProcNotation, context)
      restrict_type_or_fun_or_generic other, context
    end

    def restrict(other : Generic, context)
      restrict_type_or_fun_or_generic other, context
    end

    def restrict(other : Metaclass, context)
      restrict_type_or_fun_or_generic other, context
    end

    def restrict_type_or_fun_or_generic(other, context)
      types = union_types.compact_map do |type|
        type.restrict(other, context).as(Type?)
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

      generic_class = generic_class.as(GenericClassType)

      if other.named_args
        unless generic_class.is_a?(NamedTupleType)
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
            arg_types_tuple = context.type_lookup.program.tuple_of(arg_types)

            restricted = arg_types_tuple.restrict(type_var.exp, context)
            return nil unless restricted == arg_types_tuple

            i += count
          else
            arg_type = types[i]
            restricted = arg_type.restrict(type_var, context)
            return unless restricted == arg_type

            i += 1
          end
        end

        return self
      end

      if generic_class.type_vars.size != other.type_vars.size
        other.wrong_number_of "type vars", generic_class, other.type_vars.size, generic_class.type_vars.size
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
      if type_var.is_a?(NumberLiteral)
        case other_type_var
        when NumberLiteral
          if type_var == other_type_var
            return type_var
          end
        when Path
          if other_type_var.names.size == 1
            context.set_free_var(other_type_var.names.first, type_var)
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
        type_var.restriction_of?(other_type_var, context.owner)
      elsif context.strict?
        type_var == other_type_var
      else
        type_var.restrict(other_type_var, context) == type_var
      end
    end
  end

  class TupleInstanceType
    def restriction_of?(other : TupleInstanceType, owner)
      return true if self == other || self.implements?(other)

      false
    end

    def restrict(other : Generic, context)
      generic_class = context.type_lookup.lookup_type other.name
      return super unless generic_class == self.generic_class

      generic_class = generic_class.as(TupleType)

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
            arg_types_tuple = context.type_lookup.program.tuple_of(arg_types)

            restricted = arg_types_tuple.restrict(type_var.exp, context)
            return nil unless restricted == arg_types_tuple

            i += count
          else
            arg_type = tuple_types[i]
            restricted = arg_type.restrict(type_var, context)
            return unless restricted == arg_type

            i += 1
          end
        end

        return self
      else
        return nil unless other.type_vars.size == tuple_types.size

        tuple_types.zip(other.type_vars) do |tuple_type, type_var|
          restricted = tuple_type.restrict(type_var, context)
          return nil unless restricted == tuple_type
        end
      end

      self
    end

    def restrict(other : TupleInstanceType, context)
      self.implements?(other) ? self : nil
    end
  end

  class NamedTupleInstanceType
    def restriction_of?(other : NamedTupleInstanceType, owner)
      return true if self == other || self.implements?(other)

      false
    end

    def restrict(other : Generic, context)
      generic_class = context.type_lookup.lookup_type other.name
      return super unless generic_class == self.generic_class

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

        restricted = self_type.restrict(other_type, context)
        return nil unless restricted
      end

      self
    end

    def restrict(other : NamedTupleInstanceType, context)
      self.implements?(other) ? self : nil
    end
  end

  class IncludedGenericModule
    def restriction_of?(other : Type, owner)
      @module.restriction_of?(other, owner)
    end

    def restrict(other : Generic, context)
      generic_module = context.type_lookup.lookup_type other.name
      return super unless generic_module == @module

      generic_module = generic_module.as(GenericModuleType)
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
    def restriction_of?(other : GenericClassInstanceType, owner)
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

    def restriction_of?(other : Type, owner)
      @extended_class.restriction_of?(other, owner)
    end

    def restrict(other : Generic, context)
      generic_class = context.type_lookup.lookup_type other.name
      return super unless generic_class == @extended_class

      generic_class = generic_class.as(GenericClassType)
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
    def restriction_of?(other : Type, owner)
      other = other.base_type if other.is_a?(VirtualType)
      base_type.subclass_of?(other) || other.subclass_of?(base_type)
    end

    def restrict(other : Type, context)
      other = other.remove_alias

      if self == other
        self
      elsif other.is_a?(UnionType)
        types = other.union_types.compact_map do |t|
          restrict(t, context).as(Type?)
        end
        program.type_merge types
      elsif other.is_a?(VirtualType)
        result = base_type.restrict(other.base_type, context) || other.base_type.restrict(base_type, context)
        result ? result.virtual_type : nil
      elsif other.subclass_of?(self.base_type)
        other.virtual_type
      elsif self.base_type.subclass_of?(other)
        self
      elsif other.module?
        if base_type.implements?(other)
          self
        else
          types = base_type.subclasses.compact_map do |subclass|
            subclass.virtual_type.restrict(other, context).as(Type?)
          end
          program.type_merge_union_of types
        end
      else
        nil
      end
    end

    def restrict(other : Generic, context)
      types = base_type.subclasses.compact_map do |subclass|
        subclass.virtual_type.restrict(other, context).as(Type?)
      end
      program.type_merge_union_of types
    end
  end

  class NonGenericModuleType
    def restrict(other, context)
      super || including_types.try(&.restrict(other, context))
    end
  end

  class AliasType
    def restriction_of?(other, owner)
      return true if self == other

      remove_alias.restriction_of?(other, owner)
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
      instance_type == restricted ? self : nil
    end

    def restrict(other : VirtualMetaclassType, context)
      restricted = instance_type.restrict(other.instance_type.base_type, context)
      restricted ? self : nil
    end

    def restriction_of?(other : VirtualMetaclassType, owner)
      restriction_of?(other.base_type.metaclass, owner)
    end
  end

  class GenericClassInstanceMetaclassType
    def restrict(other : Metaclass, context)
      restricted = instance_type.restrict(other.name, context)
      instance_type == restricted ? self : nil
    end

    def restrict(other : MetaclassType, context)
      return self if instance_type.generic_class.metaclass == other

      restricted = instance_type.restrict(other.instance_type, context)
      restricted ? self : nil
    end
  end

  class ProcInstanceType
    def restrict(other : ProcNotation, context)
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
            input_arg_types_tuple = context.type_lookup.program.tuple_of(input_arg_types)

            restricted = input_arg_types_tuple.restrict(input.exp, context)
            return nil unless restricted == input_arg_types_tuple

            i += count
          else
            arg_type = arg_types[i]
            restricted = arg_type.restrict(input, context)
            return unless restricted == arg_type

            i += 1
          end
        end
      else
        return nil if arg_types.size != inputs_size

        if inputs
          inputs.zip(arg_types) do |input, my_input|
            restricted = my_input.restrict(input, context)
            return nil unless restricted == my_input
          end
        end
      end

      if output
        my_output = self.return_type
        if my_output.no_return?
          # Ok, NoReturn can be "cast" to anything
        else
          restricted = my_output.restrict(output, context)
          return nil unless restricted == my_output
        end

        self
      else
        program.proc_of(arg_types + [program.void])
      end
    end

    def restrict(other : ProcInstanceType, context)
      compatible_with?(other) ? other : nil
    end

    def restrict(other : Generic, context)
      generic_class = context.type_lookup.lookup_type other.name
      return super unless generic_class.is_a?(ProcType)

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
            arg_types_tuple = context.type_lookup.program.tuple_of(arg_types)

            restricted = arg_types_tuple.restrict(type_var.exp, context)
            return nil unless restricted == arg_types_tuple

            i += count
          else
            arg_type = proc_types[i]
            restricted = arg_type.restrict(type_var, context)
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
        restricted = proc_type.restrict other_type_var, context
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
end
