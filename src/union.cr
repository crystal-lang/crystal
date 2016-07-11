# A union type represents the possibility of a variable or an expression
# having more than one possible type at compile time.
#
# When invoking a method on a union type, the language checks that the
# method exists and can be resolved (typed) for each type in the union.
# For this reason, adding instance methods to `Union` makes no sense and
# has no effect. However, adding class method to `Union` is possible
# and can be useful. One example is parsing `JSON` into one of many
# possible types.
#
# Union is special in that it is a generic type but instantiating it
# might not return a union type:
#
# ```
# Union(Int32 | String)      # => (Int32 | String)
# Union(Int32)               # => Int32
# Union(Int32, Int32, Int32) # => Int32
# ```
struct Union
  # Returns `true` if this union includes the `Nil` type.
  #
  # ```
  # (Int32 | String).nilable? # => false
  # (Int32 | Nil).nilable?    # => true
  # ```
  def self.nilable?
    {{ T.any? &.==(::Nil) }}
  end
end
