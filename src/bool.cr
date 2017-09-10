# Bool has only two possible values: `true` and `false`. They are constructed using these literals:
#
# ```
# true  # A Bool that is true
# false # A Bool that is false
# ```
struct Bool
  # Bitwise OR. Returns `true` if this bool or *other* is `true`, otherwise returns `false`.
  #
  # ```
  # false | false # => false
  # false | true  # => true
  # true | false  # => true
  # true | true   # => true
  # ```
  def |(other : Bool)
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
  def &(other : Bool)
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
  def ^(other : Bool)
    self != other
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    hasher.bool(self)
  end

  # Returns `"true"` for `true` and `"false"` for `false`.
  def to_s
    self ? "true" : "false"
  end

  # Appends `"true"` for `true` and `"false"` for `false` to the given IO.
  def to_s(io)
    io << to_s
  end

  def clone
    self
  end
end
