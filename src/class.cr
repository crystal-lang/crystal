class Class
  def inspect(io : IO) : Nil
    to_s(io)
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.class(self)
  end

  # Returns whether this class is the same as *other*.
  #
  # ```
  # Int32 == Int32  # => true
  # Int32 == String # => false
  # ```
  def ==(other : Class) : Bool
    crystal_type_id == other.crystal_type_id
  end

  # Returns whether this class inherits or includes *other*.
  #
  # ```
  # Int32 < Number  # => true
  # Int32 < Value   # => true
  # Int32 < Int32   # => false
  # Int32 <= String # => false
  # ```
  def <(other : T.class) : Bool forall T
    # This is so that the method is expanded differently for each type
    {% @type %}
    other._gt(self)
  end

  # Returns whether this class inherits or includes *other*, or
  # is equal to *other*.
  #
  # ```
  # Int32 < Number  # => true
  # Int32 < Value   # => true
  # Int32 <= Int32  # => true
  # Int32 <= String # => false
  # ```
  def <=(other : T.class) : Bool forall T
    # This is so that the method is expanded differently for each type
    {% @type %}
    other._gte(self)
  end

  # Returns whether *other* inherits or includes `self`.
  #
  # ```
  # Number > Int32  # => true
  # Number > Number # => false
  # Number > Object # => false
  # ```
  def >(other : T.class) : Bool forall T
    # This is so that the method is expanded differently for each type
    {% @type %}
    other._lt(self)
  end

  # Returns whether *other* inherits or includes `self`, or is equal
  # to `self`.
  #
  # ```
  # Number >= Int32  # => true
  # Number >= Number # => true
  # Number >= Object # => false
  # ```
  def >=(other : T.class) forall T
    # This is so that the method is expanded differently for each type
    {% @type %}
    other._lte(self)
  end

  # :nodoc:
  def _lt(other : T.class) forall T
    {{ @type < T }}
  end

  # :nodoc:
  def _lte(other : T.class) forall T
    {{ @type <= T }}
  end

  # :nodoc:
  def _gt(other : T.class) forall T
    {{ @type > T }}
  end

  # :nodoc:
  def _gte(other : T.class) forall T
    {{ @type >= T }}
  end

  def ===(other)
    other.is_a?(self)
  end

  # Returns the name of this class.
  #
  # ```
  # String.name # => "String"
  # ```
  def name : String
    {{ @type.name.stringify }}
  end

  # Casts *other* to this class.
  #
  # This is the same as using `as`, but allows the class to be passed around as
  # an argument. See the
  # [documentation on as](//crystal-lang.org/docs/syntax_and_semantics/as.html)
  # for more information.
  #
  # ```
  # klass = Int32
  # number = [99, "str"][0]
  # typeof(number)             # => (String | Int32)
  # typeof(klass.cast(number)) # => Int32
  # ```
  def cast(other) : self
    other.as(self)
  end

  # Returns the union type of `self` and *other*.
  #
  # ```
  # Int32 | Char # => (Int32 | Char)
  # ```
  def self.|(other : U.class) forall U
    t = uninitialized self
    u = uninitialized U
    typeof(t, u)
  end

  # Returns `true` if `nil` is an instance of this type.
  #
  # ```
  # Int32.nilable?            # => false
  # Nil.nilable?              # => true
  # (Int32 | String).nilable? # => false
  # (Int32 | Nil).nilable?    # => true
  # NoReturn.nilable?         # => false
  # Value.nilable?            # => true
  # ```
  def nilable? : Bool
    {{ @type >= Nil }}
  end

  def to_s(io : IO) : Nil
    io << {{ @type.name.stringify }}
  end

  def dup
    self
  end

  def clone
    self
  end
end
