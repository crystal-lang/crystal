require "../syntax/ast"
require "../types"

# Here is the logic for deciding two things:
#
# 1. Whether a method should come before another one when considering overloads.
#    This is what `compare_strictness` and `restriction_of?` are for.
# 2. What's the resulting type of filtering a type by a restriction.
#    This is what `restrict` is for.
#
# If `a.restriction_of?(b)` is true, it means that `a` should come before `b`
# when considering restrictions. This applies almost always to AST nodes, which
# are sometimes resolved to see if a type inherits another one (and so it should
# be considered before that type), but can apply to types when arguments have a
# fixed type (mostly for primitive methods and abstract defs, though we should
# get rid of this to simplify things).
#
# A similar logic applies to a `Def`, where this logic is applied for each of
# the arguments, though here the number of arguments, splat index and other
# factors are considered. If `a.compare_strictness(b) == 0`, for `a` and `b`
# being `Def`s, then it means `a` and `b` are equivalent, and so when adding `b`
# to a type's methods it will replace `a`.
#
# The method `restrict` is different in that the return value is not a boolean,
# but a type, and computing it might be a bit more expensive. For example when
# restricting `Int32 | String` against `Int32`, the result is `Int32`.

module Crystal
  class ASTNode
    def restriction_of?(other : Underscore, owner, self_free_vars = nil, other_free_vars = nil)
      true
    end

    def restriction_of?(other : ASTNode, owner, self_free_vars = nil, other_free_vars = nil)
      self == other
    end

    def restriction_of?(other : Type, owner, self_free_vars = nil, other_free_vars = nil)
      false
    end

    def restriction_of?(other, owner, self_free_vars = nil, other_free_vars = nil)
      raise "BUG: called #{self}.restriction_of?(#{other})"
    end
  end

  class Self
    def restriction_of?(type : Type, owner, self_free_vars = nil, other_free_vars = nil)
      owner.restriction_of?(type, owner, self_free_vars, other_free_vars)
    end

    def restriction_of?(type : Self, owner, self_free_vars = nil, other_free_vars = nil)
      true
    end

    def restriction_of?(type : ASTNode, owner, self_free_vars = nil, other_free_vars = nil)
      false
    end
  end

  struct DefWithMetadata
    # Compares two defs based on overload order. Has a return value similar to
    # `Comparable`; that is, `self.compare_strictness(other)` returns:
    #
    # * `-1` if `self` is a stricter def than *other*;
    # * `1` if *other* is a stricter def than `self`;
    # * `0` if `self` and *other* are equivalent defs;
    # * `nil` if neither def is stricter than the other.
    def compare_strictness(other : DefWithMetadata, self_owner, *, other_owner = self_owner)
      unless self_owner.program.has_flag?("preview_overload_order")
        return compare_strictness_old(other, self_owner, other_owner: other_owner)
      end

      # If one yields and the other doesn't, neither is stricter than the other
      return nil unless self.yields == other.yields

      # We don't check for incompatible defs from positional parameters here,
      # because doing so would break transitivity, e.g.
      #
      #     def f(x = 0); end
      #     def f(x, y, z = 0); end
      #
      # The two defs are indeed incompatible, but their order can be defined
      # through the intermediate overload `def f(x, y = 0); end`.

      self_named_args = self.named_arguments
      other_named_args = other.named_arguments

      # Required named parameter in self, no corresponding named parameter in
      # other; neither is stricter than the other
      unless other.def.double_splat
        self_named_args.try &.each do |self_arg|
          unless self_arg.default_value
            unless other_named_args.try &.any?(&.external_name.== self_arg.external_name)
              return nil
            end
          end
        end
      end

      unless self.def.double_splat
        other_named_args.try &.each do |other_arg|
          unless other_arg.default_value
            unless self_named_args.try &.any?(&.external_name.== other_arg.external_name)
              return nil
            end
          end
        end
      end

      self_stricter = true
      other_stricter = true

      # Compare all corresponding parameters based on subsumption order
      each_corresponding_param(other, self_named_args, other_named_args) do |self_arg, other_arg|
        self_restriction = self_arg.type? || self_arg.restriction
        other_restriction = other_arg.type? || other_arg.restriction

        case {self_restriction, other_restriction}
        when {nil, nil}
          # Check other corresponding parameters
        when {nil, _}
          self_is_not_stricter
        when {_, nil}
          other_is_not_stricter
        else
          self_is_not_stricter unless self_restriction.restriction_of?(other_restriction, self_owner)
          other_is_not_stricter unless other_restriction.restriction_of?(self_restriction, other_owner)
        end
      end

      # The overload order is fully defined at this point if either def already
      # isn't stricter than the other
      return stricter_pair_to_num(self_stricter, other_stricter) if !self_stricter || !other_stricter

      # Combine the specificities from positional and all named signatures
      self_stricter, other_stricter = compare_specific_positional(other)

      if self_named_args || other_named_args
        self_named_args.try &.each do |self_arg|
          other_arg = other_named_args.try &.find(&.external_name.== self_arg.external_name)
          self_n, other_n = compare_specific_named(other, self_arg, other_arg)
          self_is_not_stricter if !self_n
          other_is_not_stricter if !other_n
        end

        other_named_args.try &.each do |other_arg|
          next if self_named_args.try &.any?(&.external_name.== other_arg.external_name)
          self_n, other_n = compare_specific_named(other, nil, other_arg)
          self_is_not_stricter if !self_n
          other_is_not_stricter if !other_n
        end
      else
        # If there are no named parameters at all, `(**ns)` is less specific than `()`
        if self.def.double_splat && !other.def.double_splat
          self_is_not_stricter
        elsif other.def.double_splat && !self.def.double_splat
          other_is_not_stricter
        end
      end

      stricter_pair_to_num(self_stricter, other_stricter)
    end

    private macro self_is_not_stricter
      self_stricter = false
      return nil if !other_stricter
    end

    private macro other_is_not_stricter
      other_stricter = false
      return nil if !self_stricter
    end

    # Compares two defs based on whether one def's positional parameters are
    # more specific than the other's.
    #
    # Required parameters are more specific than optional parameters, and single
    # splat parameters are the least specific.
    def compare_specific_positional(other : DefWithMetadata)
      # If self has more required positional parameters than other, the last
      # one in self must correspond to an optional or splat parameter in other,
      # otherwise other has no corresponding parameter and `compare_strictness`
      # would have already returned; hence, self is stricter than other in this
      # case.
      if self.min_size > other.min_size
        self_is_stricter
      elsif other.min_size > self.min_size
        other_is_stricter
      end

      # Bare splats aren't single splat parameters
      if self_splat_index = self.def.splat_index
        self_splat_index = nil if self.def.args[self_splat_index].name.empty?
      end
      if other_splat_index = other.def.splat_index
        other_splat_index = nil if other.def.args[other_splat_index].name.empty?
      end

      case {self_splat_index, other_splat_index}
      in {nil, nil}
        # Consider `(x0, x1 = 0, x2 = 0)` and `(y0, y1 = 0)`; both overloads can
        # take 1 or 2 arguments, but only self could take 3, so other is stricter
        # than self.
        if self.max_size > other.max_size
          other_is_stricter
        elsif other.max_size > self.max_size
          self_is_stricter
        end
      in {nil, Int32}
        # other has a splat parameter, self doesn't; self is stricter than the other
        self_is_stricter
      in {Int32, nil}
        # self has a splat parameter, other doesn't; other is stricter than self
        other_is_stricter
      in {Int32, Int32}
        # Consider `(x0, *xs)` and `(y0, y1 = 0, *ys)`; here `y1` corresponds to
        # `xs`, and splat parameter is less specific than optional parameter, so
        # other is stricter than self.
        if self_splat_index < other_splat_index
          other_is_stricter
        elsif other_splat_index < self_splat_index
          self_is_stricter
        end
      end

      no_differences
    end

    # Compares two defs based on whether one def's given named parameter is more
    # specific than the other's.
    def compare_specific_named(other : DefWithMetadata, self_arg : Arg?, other_arg : Arg?)
      self_arg_required = self_arg && !self_arg.default_value
      other_arg_required = other_arg && !other_arg.default_value

      # `n` is required in self, but not required in other; `n`'s corresponding
      # parameter in other must be optional or splat, so self is stricter than
      # the other
      if self_arg_required && !other_arg_required
        self_is_stricter
      elsif other_arg_required && !self_arg_required
        other_is_stricter
      end

      self_arg_optional = self_arg && self_arg.default_value
      other_arg_optional = other_arg && other_arg.default_value

      case {self.def.double_splat, other.def.double_splat}
      in {nil, nil}
        # Consider `(*, n = 0)` and `()`; both overloads can take no named
        # arguments, but only self could take `n`, so other is stricter than
        # self.
        if self_arg_optional && !other_arg_optional
          other_is_stricter
        elsif other_arg_optional && !self_arg_optional
          self_is_stricter
        end
      in {nil, Arg}
        # other has a splat parameter, self doesn't; self is stricter than the other
        self_is_stricter
      in {Arg, nil}
        # self has a splat parameter, other doesn't; other is stricter than self
        other_is_stricter
      in {Arg, Arg}
        # Consider `(*, **ms)` and `(*, n = 0, **ns)`; here `n` corresponds to
        # `ms`, and splat parameter is less specific than optional parameter, so
        # other is stricter than self.
        if self_arg_optional && !other_arg_optional
          self_is_stricter
        elsif other_arg_optional && !self_arg_optional
          other_is_stricter
        end
      end

      no_differences
    end

    private macro self_is_stricter
      return {true, false}
    end

    private macro other_is_stricter
      return {false, true}
    end

    private macro no_differences
      return {true, true}
    end

    # Yields each pair of corresponding parameters between `self` and *other*.
    def each_corresponding_param(other : DefWithMetadata, self_named_args, other_named_args, &)
      self_arg_index = 0
      other_arg_index = 0

      # Traverse through positional parameters, including single splats
      while self_arg_index < self.def.args.size && other_arg_index < other.def.args.size
        self_arg = self.def.args[self_arg_index]
        self_splatting = (self_arg_index == self.def.splat_index)
        break if self_splatting && self_arg.name.empty? # Start of named parameters

        other_arg = other.def.args[other_arg_index]
        other_splatting = (other_arg_index == other.def.splat_index)
        break if other_splatting && other_arg.name.empty? # Start of named parameters

        yield self_arg, other_arg

        break if self_splatting && other_splatting # Both are splat parameters

        self_arg_index += 1 unless self_splatting
        other_arg_index += 1 unless other_splatting
      end

      # Traverse through named parameters
      self_double_splat = self.def.double_splat
      other_double_splat = other.def.double_splat

      self_named_args.try &.each do |self_arg|
        other_arg = other_named_args.try &.find(&.external_name.== self_arg.external_name)
        other_arg ||= other_double_splat
        next unless other_arg

        yield self_arg, other_arg
      end

      if self_double_splat
        # Pair self's double splat with any remaining named parameters in other
        other_named_args.try &.each do |other_arg|
          next if self_named_args.try &.any?(&.external_name.== other_arg.external_name)

          yield self_double_splat, other_arg
        end

        # Double splats themselves are also corresponding named parameters
        if other_double_splat
          yield self_double_splat, other_double_splat
        end
      end
    end

    def stricter_pair_to_num(self_stricter, other_stricter)
      case {self_stricter, other_stricter}
      in {true, true}   then 0
      in {true, false}  then -1
      in {false, true}  then 1
      in {false, false} then nil
      end
    end

    def named_arguments
      if (splat_index = self.def.splat_index) && splat_index != self.def.args.size - 1
        self.def.args[splat_index + 1..]
      end
    end

    def compare_strictness_old(other : DefWithMetadata, self_owner, *, other_owner = self_owner)
      self_stricter = old_restriction_of?(other, self_owner)
      other_stricter = other.old_restriction_of?(self, other_owner)
      stricter_pair_to_num(self_stricter, other_stricter)
    end

    # this is part of `Crystal::Def#min_max_args_sizes` before #10711, provided
    # that `-Dpreview_overload_order` is not in effect
    # TODO: figure out if this can be derived from `self.min_size`
    def old_min_args_size
      if splat_index = self.def.splat_index
        args = self.def.args
        unless args[splat_index].name.empty?
          default_value_index = args.index(&.default_value)
          min_size = default_value_index || args.size
          min_size -= 1 unless default_value_index.try(&.< splat_index)
          return min_size
        end
      end
      self.min_size
    end

    def old_restriction_of?(other : DefWithMetadata, owner)
      # This is how multiple defs are sorted by 'restrictions' (?)

      # If one yields and the other doesn't, none is stricter than the other
      return false unless yields == other.yields

      self_min_size = old_min_args_size
      other_min_size = other.old_min_args_size

      # A def with more required arguments than the other comes first
      if self_min_size > other.max_size
        return true
      elsif other_min_size > max_size
        return false
      end

      self_splat_index = self.def.splat_index
      other_splat_index = other.def.splat_index

      # If I double-splat but the other doesn't, I come later
      if self.def.double_splat && !other.def.double_splat
        return false
      end

      # If the other double-splats but I don't, I come first
      if other.def.double_splat && !self.def.double_splat
        return true
      end

      # If I splat but the other doesn't, I come later
      if self_splat_index && !other_splat_index
        return false
      end

      # If the other splats but I don't, I come first
      if other_splat_index && !self_splat_index
        return true
      end

      if self_splat_index && other_splat_index
        min = Math.min(self_min_size, other_min_size)
      else
        min = Math.min(max_size, other.max_size)
      end

      self_free_vars = self.def.free_vars
      other_free_vars = other.def.free_vars

      (0...min).each do |index|
        self_arg = self.def.args[index]
        other_arg = other.def.args[index]

        self_type = self_arg.type? || self_arg.restriction
        other_type = other_arg.type? || other_arg.restriction
        return false if self_type == nil && other_type != nil
        if self_type && other_type
          # If this is a splat arg and the other not, this is not stricter than the other
          return false if index == self.def.splat_index

          return false unless self_type.restriction_of?(other_type, owner, self_free_vars, other_free_vars)
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
            return false unless self_restriction.restriction_of?(other_restriction, owner, self_free_vars, other_free_vars)
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
            return false unless self_restriction.restriction_of?(other_restriction, owner, self_free_vars, other_free_vars)
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
        return false unless self_double_splat_restriction.restriction_of?(other_double_splat_restriction, owner, self_free_vars, other_free_vars)
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
        self.def.args[splat_index + 1..-1].select { |arg| !arg.default_value }.sort_by! &.external_name
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
        args[splat_index + 1..-1].select { |arg| !arg.default_value }.sort_by! &.external_name
      else
        nil
      end
    end
  end

  class Path
    def restriction_of?(other : Path, owner, self_free_vars = nil, other_free_vars = nil)
      self_is_free_var = self_free_vars && self.single_name?.try { |name| self_free_vars.includes?(name) }
      other_is_free_var = other_free_vars && other.single_name?.try { |name| other_free_vars.includes?(name) }

      if self_is_free_var == other_is_free_var
        # TODO: if both paths are free variables, we need to detect renamed
        # variables properly instead of doing a plain name check
        return true if self == other
      end

      if !self_is_free_var && (self_type = owner.lookup_path(self))
        if !other_is_free_var && (other_type = owner.lookup_path(other))
          return self_type.restriction_of?(other_type, owner, self_free_vars, other_free_vars)
        else
          return true
        end
      end

      false
    end

    def restriction_of?(other : Union, owner, self_free_vars = nil, other_free_vars = nil)
      return false if self_free_vars && self.single_name?.try { |name| self_free_vars.includes?(name) }

      # `true` if this type is a restriction of any type in the union
      other.types.any? { |o| self.restriction_of?(o, owner, self_free_vars, other_free_vars) }
    end

    def restriction_of?(other : Generic, owner, self_free_vars = nil, other_free_vars = nil)
      # ```
      # def foo(param : T) forall T
      # end
      #
      # def foo(param : Array(Foo))
      # end
      # ```
      return false if self_free_vars && self.single_name?.try { |name| self_free_vars.includes?(name) }

      self_type = owner.lookup_path(self)
      if self_type
        other_type = owner.lookup_type?(other)
        if other_type
          return self_type.restriction_of?(other_type, owner, self_free_vars, other_free_vars)
        end
      end

      false
    end

    def restriction_of?(other : NumberLiteral, owner, self_free_vars = nil, other_free_vars = nil)
      return false if self_free_vars && self.single_name?.try { |name| self_free_vars.includes?(name) }

      # this happens when `self` and `other` are generic arguments:
      #
      # ```
      # X = 1
      #
      # def foo(param : StaticArray(Int32, X))
      # end
      #
      # def foo(param : StaticArray(Int32, 1))
      # end
      # ```
      case self_type = owner.lookup_path(self)
      when Const
        self_type.value == other
      when NumberLiteral
        self_type == other
      else
        false
      end
    end

    def restriction_of?(other : Underscore, owner, self_free_vars = nil, other_free_vars = nil)
      true
    end

    def restriction_of?(other, owner, self_free_vars = nil, other_free_vars = nil)
      false
    end
  end

  class NumberLiteral
    def restriction_of?(other : Path, owner, self_free_vars = nil, other_free_vars = nil)
      # this happens when `self` and `other` are generic arguments:
      #
      # ```
      # X = 1
      #
      # def foo(param : StaticArray(Int32, 1))
      # end
      #
      # def foo(param : StaticArray(Int32, X))
      # end
      # ```
      case other_type = owner.lookup_path(other)
      when Const
        other_type.value == self
      when NumberLiteral
        other_type == self
      else
        false
      end
    end
  end

  class Union
    def restriction_of?(other : Underscore, owner, self_free_vars = nil, other_free_vars = nil)
      true
    end

    def restriction_of?(other, owner, self_free_vars = nil, other_free_vars = nil)
      # For a union to be considered before another restriction,
      # all types in the union must be considered before
      # that restriction.
      # For example when using all subtypes of a parent type.
      types.all? &.restriction_of?(other, owner, self_free_vars, other_free_vars)
    end
  end

  class Generic
    def restriction_of?(other : Path, owner, self_free_vars = nil, other_free_vars = nil)
      # ```
      # def foo(param : Array(T)) forall T
      # end
      #
      # def foo(param : Int32)
      # end
      # ```
      #
      # Here, self is `Array`, other is `Int32`

      self_type = owner.lookup_type?(self)
      if self_type
        other_type = owner.lookup_path(other)
        if other_type
          return self_type.restriction_of?(other_type, owner, self_free_vars, other_free_vars)
        end
      end

      # `Array(T)` is always more strict than `Foo`
      #
      # Useful in cases where `Array(T)` overload must be checked before
      # `T` overload:
      # ```
      # def foo(param : T) forall T
      # end
      #
      # def foo(param : Array(T)) forall T
      # end
      #
      # foo([1])
      # ```
      true
    end

    def restriction_of?(other : Generic, owner, self_free_vars = nil, other_free_vars = nil)
      # The two `Foo(X)`s below are not equal because only one of them is bound
      # and the other one is unbound, so we compare the free variables too:
      # (`X` is an alias or a numeric constant)
      #
      # ```
      # def foo(x : Foo(X)) forall X
      # end
      #
      # def foo(x : Foo(X))
      # end
      # ```
      #
      # See also the todo in `Path#restriction_of?(Path)`
      return true if self == other && self_free_vars == other_free_vars
      return false unless name == other.name && type_vars.size == other.type_vars.size

      # Special case: NamedTuple against NamedTuple
      if (self_type = owner.lookup_type?(self)).is_a?(NamedTupleInstanceType)
        if (other_type = owner.lookup_type?(other)).is_a?(NamedTupleInstanceType)
          return self_type.restriction_of?(other_type, owner, self_free_vars, other_free_vars)
        end
      end

      type_vars.zip(other.type_vars) do |type_var, other_type_var|
        return false unless type_var.restriction_of?(other_type_var, owner, self_free_vars, other_free_vars)
      end

      true
    end
  end

  class GenericClassType
    def restriction_of?(other : GenericClassInstanceType, owner, self_free_vars = nil, other_free_vars = nil)
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

    def restrict(other : GenericClassType, context)
      self == other ? self : super
    end
  end

  class GenericClassInstanceType
    def restriction_of?(other : GenericClassType, owner, self_free_vars = nil, other_free_vars = nil)
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
    def restriction_of?(other : Metaclass, owner, self_free_vars = nil, other_free_vars = nil)
      name.restriction_of?(other.name, owner, self_free_vars, other_free_vars)
    end

    def restriction_of?(other : Path, owner, self_free_vars = nil, other_free_vars = nil)
      if other_type = owner.lookup_type?(other)
        # Special case: all metaclasses are subtypes of Class
        if other_type.program.class_type.implements?(other_type)
          return true
        end
      end

      super
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

      if parents.try &.any? &.restriction_of?(other, context.instantiated_type)
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
      self_type = context.self_restriction_type || context.instantiated_type
      restrict(self_type.instance_type, context)
    end

    def restrict(other : TypeOf, context)
      other.raise "can't use typeof in type restrictions"
    end

    def restrict(other : UnionType, context)
      restricted = nil

      other.union_types.each do |union_type|
        # Apply the restriction logic on each union type, even if we already
        # have a match, so that we can detect ambiguous calls between of
        # literal types against aliases that resolve to union types.
        restriction = restrict(union_type, context)
        restricted ||= restriction
      end

      restricted ? self : nil
    end

    def restrict(other : VirtualType, context)
      implements?(other.base_type) ? self : nil
    end

    def restrict(other : GenericClassType, context)
      parents.try &.each do |parent|
        if parent.module?
          return self if parent.restriction_of?(other, context.instantiated_type)
        else
          restricted = parent.restrict other, context
          return self if restricted
        end
      end

      nil
    end

    def restrict(other : Union, context)
      # Match all concrete types first
      free_var_count = other.types.count do |other_type|
        other_type.is_a?(Path) &&
          (first_name = other_type.single_name?) &&
          context.has_unbound_free_var?(first_name)
      end
      if free_var_count > 1
        other.raise "can't specify more than one free var in union restriction"
      end

      types = other.types.compact_map do |ident|
        restrict(ident, context).as(Type?)
      end
      types.size > 0 ? program.type_merge_union_of(types) : nil
    end

    def restrict(other : Path, context)
      if first_name = other.single_name?
        if context.has_unbound_free_var?(first_name)
          return context.bind_free_var(first_name, self)
        end
      end

      if first_name
        owner = context.instantiated_type

        # Special case: if we have an *uninstantiated* generic type like Foo(X)
        # and a restriction X, it matches, and we add X to the free vars.
        if owner.is_a?(GenericType)
          if owner.type_vars.includes?(first_name)
            context.bind_free_var(first_name, self)
            return self
          end
        end

        ident_type = context.bound_free_var?(other.names.first)
      end

      had_ident_type = !!ident_type
      ident_type ||= context.defining_type.lookup_path other

      if ident_type
        if ident_type.is_a?(Const)
          other.raise "#{ident_type} is not a type, it's a constant"
        end

        return restrict ident_type, context
      end

      if first_name
        if context.defining_type.type_var?(first_name)
          return context.bind_free_var(first_name, self)
        end
      end

      if had_ident_type
        other.raise "undefined constant #{other}"
      else
        other.raise_undefined_constant(context.defining_type)
      end
    end

    def restrict(other : Generic, context)
      # Special case: consider `Union(X, Y, ...)` the same as `X | Y | ...`
      generic_type = get_generic_type(other, context)
      if generic_type.is_a?(GenericUnionType)
        types = [] of Type

        other.type_vars.each do |type_var|
          if type_var.is_a?(Splat)
            splat_type = context.defining_type.lookup_type?(type_var.exp)
            return nil unless splat_type
            unless splat_type.is_a?(TupleInstanceType)
              type_var.raise "argument to splat must be a tuple type, not #{splat_type}"
            end

            splat_type.tuple_types.each do |tuple_type|
              if type = restrict(tuple_type, context)
                types << type
              end
            end
          else
            if type = restrict(type_var, context)
              types << type
            end
          end
        end

        return types.size > 0 ? program.type_merge_union_of(types) : nil
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

    def restrict(other : Arg, context)
      restrict (other.type? || other.restriction), context
    end

    def restrict(other : NumberLiteral, context)
      nil
    end

    def restrict(other : Splat, context)
      nil
    end

    def restrict(other : ASTNode, context)
      raise "BUG: unsupported restriction: #{self} vs. #{other}"
    end

    def restriction_of?(other : UnionType, owner, self_free_vars = nil, other_free_vars = nil)
      other.union_types.any? { |subtype| restriction_of?(subtype, owner, self_free_vars, other_free_vars) }
    end

    def restriction_of?(other : VirtualType, owner, self_free_vars = nil, other_free_vars = nil)
      implements? other.base_type
    end

    def restriction_of?(other : Type, owner, self_free_vars = nil, other_free_vars = nil)
      if self == other
        return true
      end

      !!parents.try &.any? &.restriction_of?(other, owner, self_free_vars, other_free_vars)
    end

    def restriction_of?(other : AliasType, owner, self_free_vars = nil, other_free_vars = nil)
      if self == other
        true
      else
        restriction_of?(other.remove_alias, owner, self_free_vars, other_free_vars)
      end
    end

    def restriction_of?(other : ASTNode, owner, self_free_vars = nil, other_free_vars = nil)
      raise "BUG: called #{self}.restriction_of?(#{other})"
    end

    def compatible_with?(type)
      self == type
    end
  end

  class UnionType
    def restriction_of?(type, owner, self_free_vars = nil, other_free_vars = nil)
      self == type || union_types.all? &.restriction_of?(type, owner, self_free_vars, other_free_vars)
    end

    def restrict(other : Union, context)
      # Match all concrete types first
      free_vars, other_types = other.types.partition do |other_type|
        other_type.is_a?(Path) &&
          (first_name = other_type.single_name?) &&
          context.has_unbound_free_var?(first_name)
      end
      if free_vars.size > 1
        other.raise "can't specify more than one free var in union restriction"
      end

      types = [] of Type
      discarded = [] of Type
      other_types.each do |other_type|
        self.union_types.each do |type|
          next if discarded.includes?(type)

          restricted = type.restrict(other_type, context)
          if restricted
            types << restricted
            discarded << type
          end
        end
      end

      # If there is a free var, we match it last and it'll be the union of the
      # remaining types in self
      if free_var = free_vars.first?
        # If we restrict `T` against `T | U forall U`, then `U` can be any type;
        # the smallest type satisfying the restriction is Union() or NoReturn,
        # but we don't want that, so we make this a substitution failure.
        if discarded.size == self.union_types
          return nil
        end

        if remaining_type = program.type_merge_union_of(self.union_types - discarded)
          if restricted = remaining_type.restrict(free_var, context)
            types << restricted
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

  class GenericInstanceType
    def restriction_of?(other : GenericType, owner, self_free_vars = nil, other_free_vars = nil)
      return true if generic_type == other
      super
    end

    def restriction_of?(other : GenericInstanceType, owner, self_free_vars = nil, other_free_vars = nil)
      return super unless generic_type == other.generic_type

      type_vars.each do |name, type_var|
        other_type_var = other.type_vars[name]
        if type_var.is_a?(Var) && other_type_var.is_a?(Var)
          # This overload can be called when the restriction node has a type due
          # to e.g. AbstractDefChecker; generic instances shall behave like AST
          # nodes when def restrictions are considered, i.e. all generic type
          # variables are covariant.
          return false unless type_var.type.implements?(other_type_var.type)
        else
          return false unless type_var == other_type_var
        end
      end

      true
    end

    def restrict(other : GenericType, context)
      return self if generic_type == other

      parents.try &.each do |parent|
        if parent.module?
          return self if parent.restriction_of?(other, context.instantiated_type)
        else
          restricted = parent.restrict other, context
          return self if restricted
        end
      end

      nil
    end

    def restrict(other : Generic, context)
      generic_type = get_generic_type(other, context)
      generic_type = generic_type.remove_alias if generic_type.is_a? AliasType
      return super unless generic_type == self.generic_type

      generic_type = generic_type.as(GenericType)

      # We match named tuples in NamedTupleInstanceType
      if generic_type.is_a?(NamedTupleType)
        return nil
      end

      if other.named_args
        other.raise "can only instantiate NamedTuple with named arguments"
      end

      # Consider the case of a splat in the type vars
      splat_index = self.splat_index
      splat_given = other.type_vars.any?(Splat)
      if splat_index || splat_given
        types = Array(Type).new(type_vars.size)
        i = 0
        type_vars.each_value do |var|
          return nil unless var.is_a?(Var)

          var_type = var.type
          if i == splat_index
            types.concat(var_type.as(TupleInstanceType).tuple_types)
          else
            types << var_type
          end
          i += 1
        end

        # We are `(A, B, *C)`, they are `(T)`; matching would always fail
        if splat_index && !splat_given
          min_needed = generic_type.type_vars.size - 1
          if other.type_vars.size < min_needed
            other.wrong_number_of "type vars", generic_type, other.type_vars.size, "#{min_needed}+"
          end
        end

        # We are `(A)`, they are `(T, U, *V)`; matching would always fail
        if !splat_index && splat_given
          non_splat_count = other.type_vars.count { |type_var| !type_var.is_a?(Splat) }
          if non_splat_count > generic_type.type_vars.size
            other.wrong_number_of "type vars", generic_type, "#{non_splat_count}+", generic_type.type_vars.size
          end
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
            arg_types_tuple = context.instantiated_type.program.tuple_of(arg_types)

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

      if other.type_vars.size != generic_type.type_vars.size
        other.wrong_number_of "type vars", generic_type, other.type_vars.size, generic_type.type_vars.size
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

    def restrict(other : GenericInstanceType, context)
      return super unless generic_type == other.generic_type

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
          if first_name = other_type_var.single_name?
            # If the free variable is already set to another
            # number, there's no match
            if existing = context.bound_free_var?(first_name)
              return existing == type_var ? existing : nil
            end

            # If the free variable is not yet bound, there is a match
            if context.has_unbound_free_var?(first_name)
              context.bind_free_var(first_name, type_var)
              return type_var
            end
          end
        else
          # Restriction is not possible (maybe return nil here?)
        end
      else
        type_var = type_var.type? || type_var
      end

      unless other_type_var.is_a?(NumberLiteral)
        other_type_var = other_type_var.type? || other_type_var
      end

      if type_var.is_a?(ASTNode)
        type_var.restriction_of?(other_type_var, context.instantiated_type)
      else
        # To prevent infinite recursion, it checks equality between
        # `type_var` and `other_type_var` directly before try to restrict
        # `type_var` by `other_type_var`.
        type_var == other_type_var || type_var.restrict(other_type_var, context) == type_var
      end
    end
  end

  class TupleInstanceType
    def restriction_of?(other : TupleInstanceType, owner, self_free_vars = nil, other_free_vars = nil)
      return true if self == other || self.implements?(other)

      false
    end

    def restrict(other : Generic, context)
      generic_type = get_generic_type(other, context)
      return super unless generic_type == self.generic_type

      if other.named_args
        other.raise "can only instantiate NamedTuple with named arguments"
      end

      # Consider the case of a splat in the type vars
      splat_given = other.type_vars.any?(Splat)
      if splat_given
        found_splat = false
        i = 0
        other.type_vars.each do |type_var|
          if type_var.is_a?(Splat)
            type_var.raise "can't specify more than one splat in restriction" if found_splat
            found_splat = true

            count = tuple_types.size - (other.type_vars.size - 1)
            return nil unless count >= 0

            arg_types = tuple_types[i, count]
            arg_types_tuple = context.instantiated_type.program.tuple_of(arg_types)

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
    def restriction_of?(other : NamedTupleInstanceType, owner, self_free_vars = nil, other_free_vars = nil)
      return true if self == other || self.implements?(other)

      false
    end

    def restrict(other : Generic, context)
      generic_type = get_generic_type(other, context)
      return super unless generic_type == self.generic_type

      unless other.type_vars.empty?
        other.raise "can only instantiate NamedTuple with named arguments"
      end

      # Check for empty named tuples
      unless other_named_args = other.named_args
        return self.entries.empty? ? self : nil
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

  class VirtualType
    def restriction_of?(other : Type, owner, self_free_vars = nil, other_free_vars = nil)
      other = other.base_type if other.is_a?(VirtualType)
      base_type.implements?(other) || other.implements?(base_type)
    end

    def restrict(other : Type, context)
      other = other.remove_alias
      base_type = self.base_type

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
      elsif other.implements?(base_type)
        other.virtual_type
      elsif base_type.implements?(other)
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
      elsif base_type.is_a?(GenericInstanceType) && other.is_a?(GenericType)
        # Consider the case of Foo(Int32) vs. Bar(T), with Bar(T) < Foo(T):
        # we want to return Bar(Int32), so we search in Bar's generic instantiations
        types = other.instantiated_types.compact_map do |instance|
          next if instance.unbound? || instance.abstract?
          instance.virtual_type if instance.implements?(base_type)
        end
        program.type_merge_union_of types
      else
        nil
      end
    end

    def restrict(other : Generic, context)
      # Restrict first against the base type
      restricted = base_type.restrict(other, context)
      if restricted
        return restricted.virtual_type
      end

      types = base_type.subclasses.compact_map do |subclass|
        subclass.virtual_type.restrict(other, context).as(Type?)
      end
      program.type_merge_union_of types
    end
  end

  class VirtualMetaclassType
    def restrict(other : Metaclass, context)
      instance_type.restrict(other.name, context).try &.metaclass
    end
  end

  class NonGenericModuleType
    def restrict(other, context)
      super || including_types.try(&.restrict(other, context))
    end
  end

  class GenericModuleInstanceType
    def restrict(other : Type, context)
      super || including_types.try(&.restrict(other, context))
    end
  end

  class AliasType
    def restriction_of?(other : Underscore, owner, self_free_vars = nil, other_free_vars = nil)
      true
    end

    def restriction_of?(other, owner, self_free_vars = nil, other_free_vars = nil)
      return true if self == other

      remove_alias.restriction_of?(other, owner, self_free_vars, other_free_vars)
    end

    def restrict(other : Path, context)
      if first_name = other.single_name?
        if context.has_unbound_free_var?(first_name)
          return context.bind_free_var(first_name, self)
        end
      end

      other_type = context.defining_type.lookup_path other
      if other_type
        if other_type == self
          return self
        end
      else
        if first_name = other.single_name?
          if context.defining_type.type_var?(first_name)
            return context.bind_free_var(first_name, self)
          else
            other.raise_undefined_constant(context.defining_type)
          end
        end
      end

      remove_alias.restrict(other, context)
    end

    def restrict(other : AliasType, context)
      return self if self == other

      if !self.simple? && !other.simple?
        return nil
      end

      remove_alias.restrict(other, context)
    end

    def restrict(other, context)
      return self if self == other

      remove_alias.restrict(other, context)
    end
  end

  class TypeDefType
    def restrict(other : UnionType, context)
      super
    end

    def restrict(other : AliasType, context)
      other = other.remove_alias
      return self if self == other
      restrict(other, context)
    end

    def restrict(other : Type, context)
      return self if self == other

      restricted = typedef.restrict(other, context)
      if restricted == typedef
        self
      elsif restricted.is_a?(UnionType)
        program.type_merge(restricted.union_types.map { |t| t == typedef ? self : t })
      else
        restricted
      end
    end
  end

  class MetaclassType
    def restrict(other : Metaclass, context)
      restricted = instance_type.restrict(other.name, context)
      instance_type == restricted ? self : nil
    end

    def restrict(other : VirtualMetaclassType, context)
      # A module class can't be restricted into a class
      return nil if instance_type.module?

      restricted = instance_type.restrict(other.instance_type.base_type, context)
      restricted ? self : nil
    end

    def restriction_of?(other : VirtualMetaclassType, owner, self_free_vars = nil, other_free_vars = nil)
      restriction_of?(other.base_type.metaclass, owner, self_free_vars, other_free_vars)
    end
  end

  class GenericClassInstanceMetaclassType
    def restrict(other : Metaclass, context)
      restricted = instance_type.restrict(other.name, context)
      instance_type == restricted ? self : nil
    end

    def restrict(other : MetaclassType, context)
      return self if instance_type.generic_type.metaclass == other

      restricted = instance_type.restrict(other.instance_type, context)
      restricted ? self : nil
    end
  end

  class GenericModuleInstanceMetaclassType
    def restrict(other : Metaclass, context)
      restricted = instance_type.restrict(other.name, context)
      instance_type == restricted ? self : nil
    end

    def restrict(other : MetaclassType, context)
      return self if instance_type.generic_type.metaclass == other

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
      if inputs && inputs.any?(Splat)
        i = 0
        inputs.each do |input|
          if input.is_a?(Splat)
            count = arg_types.size - (inputs.size - 1)
            return nil unless count >= 0

            input_arg_types = arg_types[i, count]
            input_arg_types_tuple = context.instantiated_type.program.tuple_of(input_arg_types)

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
      generic_type = get_generic_type(other, context)
      return super unless generic_type.is_a?(ProcType)

      # Consider the case of a splat in the type vars
      splat_given = other.type_vars.any?(Splat)
      if splat_given
        proc_types = arg_types + [return_type]

        i = 0
        other.type_vars.each do |type_var|
          if type_var.is_a?(Splat)
            count = proc_types.size - (other.type_vars.size - 1)
            return nil unless count >= 0

            arg_types = proc_types[i, count]
            arg_types_tuple = context.instantiated_type.program.tuple_of(arg_types)

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
        # If checking the return type
        if i == other.type_vars.size - 1
          # any type matches Nil
          if nil_type?(other_type_var, context)
            # Also, all other types matched, so the matching type is this proc type
            # except that it has a Nil return type
            new_proc_arg_types = arg_types.dup
            new_proc_arg_types << program.nil_type
            return program.proc_of(new_proc_arg_types)
          end

          if return_type.no_return?
            # Ok, NoReturn can be "cast" to anything
            next
          end
        end

        proc_type = arg_types[i]? || return_type
        restricted = proc_type.restrict other_type_var, context
        return nil unless restricted == proc_type
      end

      self
    end

    def nil_type?(node, context)
      node.is_a?(Path) && context.defining_type.lookup_path(node).is_a?(NilType)
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
      return false if arg_types.size != other.arg_types.size

      arg_types.zip(other.arg_types) do |arg_type, other_arg_type|
        return false unless arg_type == other_arg_type
      end

      true
    end
  end

  class AutocastType
    # Returns true if the AST node associated with `self` denotes a value of the
    # given *type*.
    def matches_exactly?(type : Type) : Bool
      false
    end

    # Returns true if the AST node associated with `self` denotes a value that
    # may be interpreted in the given *type*, but is itself not of that type.
    def matches_partially?(type : Type) : Bool
      false
    end

    def restrict(other, context)
      if other.is_a?(Type)
        if matches_exactly?(other)
          set_exact_match(other)
          return other
        elsif !exact_match? && matches_partially?(other)
          add_match(other)
          return other
        end
      end

      literal_type = literal.type?
      type = literal_type.try(&.restrict(other, context)) || super(other, context)
      if type == self
        # if *other* is an AST node (e.g. `Path`) or a complex type (e.g.
        # `UnionType`), `@match` may be set from recursive calls to `#restrict`,
        # so we propagate any exact matches found during those calls
        type = @match || literal_type
      end
      type
    end

    def compatible_with?(type)
      matches_exactly?(type) || matches_partially?(type)
    end
  end

  class NumberAutocastType
    def matches_exactly?(type : IntegerType | FloatType) : Bool
      literal.type == type
    end

    def matches_partially?(type : IntegerType | FloatType) : Bool
      literal = self.literal

      if literal.is_a?(NumberLiteral)
        literal.representable_in?(type)
      else
        literal_type = literal.type
        (literal_type.is_a?(IntegerType) || literal_type.is_a?(FloatType)) && literal_type.subset_of?(type)
      end
    end
  end

  class SymbolAutocastType
    def matches_exactly?(type : SymbolType) : Bool
      true
    end

    def matches_partially?(type : EnumType) : Bool
      !type.find_member(literal.value).nil?
    end
  end
end

private def get_generic_type(node, context)
  name = node.name
  if name.is_a?(Crystal::Path)
    context.defining_type.lookup_path name
  else
    name.type
  end
end
