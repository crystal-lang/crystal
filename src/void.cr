{% if Crystal::VERSION == "0.18.0" %}
  # The Void type is used to represent values
  # that have no use, usually as a return type
  # of methods that only produce side effects.
  #
  # The union of Void with any other type results
  # in Void.
  #
  # Void is somewhat similar to `Nil`. The difference
  # is that `Nil` is used to mean the absence of a value,
  # and is usually combined with a type that has a value,
  # to form nilable types. Void, on the other hand,
  # can't be combined with other types.
  struct Void
    # Returns zero.
    def hash
      0
    end

    # Appends `"void"` to the given *io*
    def to_s(io)
      io << "void"
    end

    # Returns `"void"`
    def to_s
      "void"
    end
  end
{% end %}
