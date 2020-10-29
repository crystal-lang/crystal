# Bool has only two possible values: `true` and `false`. They are constructed using these literals:
#
# ```
# true  # A Bool that is true
# false # A Bool that is false
# ```
struct Bool
  include Comparable(self)

  # Bitwise OR. Returns `true` if this bool or *other* is `true`, otherwise returns `false`.
  #
  # ```
  # false | false # => false
  # false | true  # => true
  # true | false  # => true
  # true | true   # => true
  # ```
  def |(other : Bool) : Bool
    self ? true : other
  end

  # Bitwise AND. Returns `true` if this bool and *other* are `true`, otherwise returns `false`.
  #
  # ```
  # false & false # => false
  # false & true  # => false
  # true & false  # => false
  # true & true   # => true
  # ```
  def &(other : Bool) : Bool
    self ? other : false
  end

  # Exclusive OR. Returns `true` if this bool is different from *other*, otherwise returns `false`.
  #
  # ```
  # false ^ false # => false
  # false ^ true  # => true
  # true ^ false  # => true
  # true ^ true   # => false
  # ```
  def ^(other : Bool) : Bool
    self != other
  end

  # Compares this bool against another, according to their underlying value.
  #
  # ```
  # false <=> true  # => -1
  # true <=> false  # => 1
  # true <=> true   # => 0
  # false <=> false # => 0
  # ```
  def <=>(other : Bool) : Int32
    self == other ? 0 : (self ? 1 : -1)
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.bool(self)
  end

  # Returns an integer derived from the boolean value, for interoperability with C-style booleans.
  #
  # The value is `1` for `true` and `0` for `false`.
  def to_unsafe : LibC::Int
    LibC::Int.new(self ? 1 : 0)
  end

  # Returns `"true"` for `true` and `"false"` for `false`.
  def to_s : String
    self ? "true" : "false"
  end

  # Appends `"true"` for `true` and `"false"` for `false` to the given IO.
  def to_s(io : IO) : Nil
    io << to_s
  end

  def clone : Bool
    self
  end
end
