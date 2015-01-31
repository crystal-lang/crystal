# Bool has only two possible values: `true` and `false`. They are constructed using these literals:
#
# ```
# true  # A Bool that is true
# false # A Bool that is false
# ```
struct Bool
  # Negates this boolean.
  #
  # ```
  # !true  #=> false
  # !false #=> true
  # ```
  def !
    self ? false : true
  end

  # Bitwise OR. Returns `true` if this bool or `other` is `true`, otherwise returns `false`.
  #
  # ```
  # false | false #=> false
  # false | true  #=> true
  # true  | false #=> true
  # true  | true  #=> true
  # ```
  def |(other : Bool)
    self ? true : other
  end

  # Bitwise AND. Returns `true` if this bool and `other` and `true`, otherwise returns `false`.
  #
  # ```
  # false & false #=> false
  # false & true  #=> false
  # true  & false #=> false
  # true  & true  #=> true
  # ```
  def &(other : Bool)
    self ? other : false
  end

  # Returns a hash value for this boolean: 0 for false, 1 for true.
  def hash
    self ? 1 : 0
  end

  # Returns `"true"` for `true` and `"false"` for `false`.
  def to_s
    self ? "true" : "false"
  end

  # Appends `"true"` for `true` and `"false"` for `false` to the given IO.
  def to_s(io)
    io << to_s
  end
end
