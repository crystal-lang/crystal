module Crystal
  # Context information about a method lookup match.
  #
  # For example, given:
  #
  # ```
  # class Foo
  #   class Baz
  #   end
  #
  #   def method
  #     Baz.new
  #   end
  # end
  #
  # class Bar < Foo
  #   class Baz
  #   end
  # end
  #
  # Bar.new.method # => #<Foo::Baz:0x10c1a2fc0>
  # ```
  #
  # we have that:
  #
  # * `defining_type` is `Foo`, because it's the type that define the method
  # * `instantiated_type` is `Bar`, because the method was invoked, and thus
  #    instantiated there
  #
  # `defining_type` is needed because when we search types in `method`,
  # we must search them starting from `Foo`, not from `Bar`.
  # `instantiated_type` is needed because method resolution will start
  # from `Bar`.
  #
  # TODO: this might slightly change in the future, we should probably instantiate
  # the method on `Foo+` to avoid having duplicated methods, at least for reference
  # types, even though that might lead to broader method resolutions (because
  # a method call in `method` will now be searched in `Foo+`, not in `Bar`)
  class MatchContext
    # The type where the method was instantiated
    property instantiated_type : Type

    # The type that defines the method
    property defining_type : Type

    # Any instance variables associated with the method instantiation
    getter bound_free_vars : Hash(String, TypeVar)?

    # Def free variables (`def ... forall X, Y`)
    property def_free_vars : Array(String)?

    # The type that represents `self` (overriding `instantiated_type`), used to
    # resolve restrictions properly when a macro def is about to be copied to a
    # subtype
    property self_restriction_type : Type?

    def initialize(@instantiated_type, @defining_type, @bound_free_vars = nil, @def_free_vars = nil, @self_restriction_type = nil)
    end

    def bound_free_var?(name)
      @bound_free_vars.try &.[name]?
    end

    def bind_free_var(name, type)
      bound_free_vars = @bound_free_vars ||= {} of String => TypeVar
      type = type.remove_literal if type.is_a?(Type)
      bound_free_vars[name] = type
    end

    def has_unbound_free_var?(name)
      return false if bound_free_var?(name)
      return true if @def_free_vars.try &.includes?(name)

      defining_type.metaclass? && defining_type.type_var?(name)
    end

    # Returns the type that corresponds to using `self` when looking
    # a type relative to this context.
    #
    # For example, given:
    #
    # ```
    # class Foo
    #   def foo(&block : self ->)
    #     ...
    #   end
    # end
    #
    # class Bar < Foo
    # end
    #
    # Bar.new.foo { |x| }
    # ```
    #
    # it's expected that the block argument `x` will be of type `Bar`, not `Foo`.
    def self_type : Type
      instantiated_type.instance_type
    end

    def clone
      MatchContext.new(@instantiated_type, @defining_type, @bound_free_vars.dup, @def_free_vars.dup, @self_restriction_type)
    end
  end

  # A method lookup match.
  class Match
    # The method that was matched
    getter def : Def

    # The type of the arguments of the matched method.
    # These might be a subset of the types of the method call because
    # of restrictions and overloads.
    getter arg_types : Array(Type)

    # The type of the named arguments of the matched method.
    # These might be a subset of the types of the method call because
    # of restrictions and overloads.
    getter named_arg_types : Array(NamedArgumentType)?

    # Context information associated with this match
    getter context : MatchContext

    def initialize(@def, @arg_types, @context, @named_arg_types = nil)
    end

    def remove_literals
      @arg_types.map!(&.remove_literal)
      @named_arg_types.try &.map! { |arg| NamedArgumentType.new(arg.name, arg.type.remove_literal) }
    end
  end

  struct Matches
    include Enumerable(Match)

    property matches : Array(Match)?
    property cover : Bool | Cover | Nil
    property owner : Type?

    def initialize(@matches, @cover, @owner = nil, @success = true)
    end

    def cover_all?
      cover = @cover
      matches = @matches
      @success && matches && matches.size > 0 && (cover == true || (cover.is_a?(Cover) && cover.all?))
    end

    def empty?
      return true unless @success

      if matches = @matches
        matches.empty?
      else
        true
      end
    end

    def each(&)
      @success && @matches.try &.each do |match|
        yield match
      end
    end

    def size
      @matches.try(&.size) || 0
    end

    def [](*args)
      Matches.new(@matches.try &.[](*args), @cover, @owner, @success)
    end
  end
end
