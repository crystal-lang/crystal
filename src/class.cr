class Class
  def inspect(io)
    to_s(io)
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.class(self)
  end

  def ==(other : Class)
    crystal_type_id == other.crystal_type_id
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

  # Returns `true` if this class is `Nil`.
  #
  # ```
  # Int32.nilable? # => false
  # Nil.nilable?   # => true
  # ```
  def nilable?
    self == ::Nil
  end

  def to_s(io)
    io << name
  end

  def dup
    self
  end

  def clone
    self
  end
end
