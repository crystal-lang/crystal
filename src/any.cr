abstract struct Any
  # Assumes the underlying value is an `Array` or `Hash` and returns its size.
  # Raises if the underlying value is not an `Array` or `Hash`.
  def size : Int
    case object = @raw
    when Array
      object.size
    when Hash
      object.size
    else
      raise "Expected Array or Hash for #size, not #{object.class}"
    end
  end

  # Checks that the underlying value is `Bool`, and returns its value.
  # Raises otherwise.
  def as_bool : Bool
    @raw.as(Bool)
  end

  # Checks that the underlying value is `Bool`, and returns its value.
  # Returns `nil` otherwise.
  def as_bool? : Bool?
    @raw.as?(Bool)
  end

  # Checks that the underlying value is `Float64`, and returns its value.
  # Raises otherwise.
  def as_f : Float64
    @raw.as(Float64)
  end

  # Checks that the underlying value is `Float64`, and returns its value.
  # Returns `nil` otherwise.
  def as_f? : Float64?
    @raw.as?(Float64)
  end

  # Checks that the underlying value is `Nil`, and returns `nil`.
  # Raises otherwise.
  def as_nil : Nil
    @raw.as(Nil)
  end

  # Checks that the underlying value is `String`, and returns its value.
  # Raises otherwise.
  def as_s : String
    @raw.as(String)
  end

  # Checks that the underlying value is `String`, and returns its value.
  # Returns `nil` otherwise.
  def as_s? : String?
    @raw.as?(String)
  end

  # Checks that the underlying value is `Int64`, and returns its value as `Int32`.
  # Raises otherwise.
  def as_i : Int32
    as_i64.to_i
  end

  # Checks that the underlying value is `Int64`, and returns its value as `Int32`.
  # Returns `nil` otherwise.
  def as_i? : Int32?
    as_i64?.try &.to_i
  end

  # Checks that the underlying value is `Int64`, and returns its value.
  # Raises otherwise.
  def as_i64 : Int64
    @raw.as(Int64)
  end

  # Checks that the underlying value is `Int64`, and returns its value.
  # Returns `nil` otherwise.
  def as_i64? : Int64?
    @raw.as?(Int64)
  end

  # Checks that the underlying value is `Bytes`, and returns its value.
  # Raises otherwise.
  def as_bytes : Bytes
    @raw.as(Bytes)
  end

  # Checks that the underlying value is `Bytes`, and returns its value.
  # Returns `nil` otherwise.
  def as_bytes? : Bytes?
    @raw.as?(Bytes)
  end

  # :nodoc:
  def inspect(io)
    @raw.inspect(io)
  end

  # :nodoc:
  def to_s(io)
    @raw.to_s(io)
  end

  # :nodoc:
  def pretty_print(pp)
    @raw.pretty_print(pp)
  end

  # Returns `true` if both `self` and *other*'s raw object are equal.
  def ==(other : Any)
    raw == other.raw
  end

  # Returns `true` if the raw object is equal to *other*.
  def ==(other)
    raw == other
  end

  # See `Object#hash(hasher)`
  def_hash raw
end

macro any_classes(type)
  class Object
    def ===(other : {{type.id}}::Any)
      self === other.raw
    end
  end

  struct Value
    def ==(other : {{type.id}}::Any)
      self == other.raw
    end
  end

  class Reference
    def ==(other : {{type.id}}::Any)
      self == other.raw
    end
  end

  class Array
    def ==(other : {{type.id}}::Any)
      self == other.raw
    end
  end

  class Hash
    def ==(other : {{type.id}}::Any)
      self == other.raw
    end
  end

  class Regex
    def ===(other : {{type.id}}::Any)
      value = self === other.raw
      $~ = $~
      value
    end
  end
end
