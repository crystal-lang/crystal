class Object
  def !=(other)
    !(self == other)
  end

  def ===(other)
    self == other
  end

  # Returns a string representation of this object.
  #
  # Classes must usually **not** override this method. Instead,
  # they must override `to_s(io)`, which must append to the given
  # IO object.
  def to_s
    String.build do |io|
      to_s io
    end
  end

  # Appends a string representation of this object
  # to the given IO object.
  #
  # An object must never append itself to the `io` argument,
  # as this will in turn call `to_s(io)` on it.
  abstract def to_s(io : IO)

  # Returns a String representation of this object.
  #
  # Similar to `to_s`, but usually returns more information about
  # this object.
  #
  # Classes must usually **not** override this method. Instead,
  # they must override `inspect(io)`, which must append to the
  # given IO object.
  def inspect
    String.build do |io|
      inspect io
    end
  end

  # Appends a string representation of this object
  # to the given IO object.
  #
  # Similar to `to_s(io)`, but usually appends more information
  # about this object.
  def inspect(io : IO)
    to_s io
  end

  def tap
    yield self
    self
  end

  def try
    yield self
  end

  def not_nil!
    self
  end

  macro getter(name)
    def {{name.id}}
      @{{name.id}}
    end
  end

  macro getter!(name)
    def {{name.id}}?
      @{{name.id}}
    end

    def {{name.id}}
      @{{name.id}}.not_nil!
    end
  end

  macro setter(name)
    def {{name.id}}=(@{{name.id}})
    end
  end

  macro property(name)
    getter :{{name.id}}
    setter :{{name.id}}
  end

  macro property!(name)
    getter! :{{name.id}}
    setter :{{name.id}}
  end

  macro delegate(method, to)
    def {{method.id}}
      {{to.id}}.{{method.id}}
    end
  end

  macro generate_hash(fields)
    def hash
      hash = 0
      {% for field in fields %}
        hash = 31 * hash + {{field}}.hash
      {% end %}
      hash
    end
  end

  macro generate_equals(fields)
    def ==(other : self)
      {% for field in fields %}
        return false unless {{field.id}} == other.{{field.id}}
      {% end %}
      true
    end
  end

  macro generate_equals_and_hash(fields)
    generate_equals {{fields}}
    generate_hash {{fields}}
  end
end
