# `JSON::Any` is a convenient wrapper around all possible JSON types (`JSON::Type`)
# and can be used for traversing dynamic or unknown JSON structures.
#
# ```
# obj = JSON.parse(%({"access": [{"name": "mapping", "speed": "fast"}, {"name": "any", "speed": "slow"}]}))
# obj["access"][1]["name"].as_s  # => "any"
# obj["access"][1]["speed"].as_s # => "slow"
# ```
#
# Note that methods used to traverse a JSON structure, `#[]`, `#[]?` and `#each`,
# always return a `JSON::Any` to allow further traversal. To convert them to `String`,
# `Int32`, etc., use the `as_` methods, such as `#as_s`, `#as_i`, which perform
# a type check against the raw underlying value. This means that invoking `#as_s`
# when the underlying value is not a String will raise: the value won't automatically
# be converted (parsed) to a `String`.
struct JSON::Any
  include Enumerable(self)

  # Reads a `JSON::Any` value from the given pull parser.
  def self.new(pull : JSON::PullParser)
    case pull.kind
    when :null
      new pull.read_null
    when :bool
      new pull.read_bool
    when :int
      new pull.read_int
    when :float
      new pull.read_float
    when :string
      new pull.read_string
    when :begin_array
      ary = [] of JSON::Type
      pull.read_array do
        ary << new(pull).raw
      end
      new ary
    when :begin_object
      hash = {} of String => JSON::Type
      pull.read_object do |key|
        hash[key] = new(pull).raw
      end
      new hash
    else
      raise "Unknown pull kind: #{pull.kind}"
    end
  end

  # Returns the raw underlying value, a `JSON::Type`.
  getter raw : JSON::Type

  # Creates a `JSON::Any` that wraps the given `JSON::Type`.
  def initialize(@raw : JSON::Type)
  end

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

  # Assumes the underlying value is an `Array` and returns the element
  # at the given index.
  # Raises if the underlying value is not an `Array`.
  def [](index : Int) : JSON::Any
    case object = @raw
    when Array
      Any.new object[index]
    else
      raise "Expected Array for #[](index : Int), not #{object.class}"
    end
  end

  # Assumes the underlying value is an `Array` and returns the element
  # at the given index, or `nil` if out of bounds.
  # Raises if the underlying value is not an `Array`.
  def []?(index : Int) : JSON::Any?
    case object = @raw
    when Array
      value = object[index]?
      value.nil? ? nil : Any.new(value)
    else
      raise "Expected Array for #[]?(index : Int), not #{object.class}"
    end
  end

  # Assumes the underlying value is a `Hash` and returns the element
  # with the given key.
  # Raises if the underlying value is not a `Hash`.
  def [](key : String) : JSON::Any
    case object = @raw
    when Hash
      Any.new object[key]
    else
      raise "Expected Hash for #[](key : String), not #{object.class}"
    end
  end

  # Assumes the underlying value is a `Hash` and returns the element
  # with the given key, or `nil` if the key is not present.
  # Raises if the underlying value is not a `Hash`.
  def []?(key : String) : JSON::Any?
    case object = @raw
    when Hash
      value = object[key]?
      value.nil? ? nil : Any.new(value)
    else
      raise "Expected Hash for #[]?(key : String), not #{object.class}"
    end
  end

  # Assumes the underlying value is an `Array` or `Hash` and yields each
  # of the elements or key/values, always as `JSON::Any`.
  # Raises if the underlying value is not an `Array` or `Hash`.
  def each
    case object = @raw
    when Array
      object.each do |elem|
        yield Any.new(elem), Any.new(nil)
      end
    when Hash
      object.each do |key, value|
        yield Any.new(key), Any.new(value)
      end
    else
      raise "Expected Array or Hash for #each, not #{object.class}"
    end
  end

  # Checks that the underlying value is `Nil`, and returns `nil`.
  # Raises otherwise.
  def as_nil : Nil
    @raw.as(Nil)
  end

  # Checks that the underlying value is `Bool`, and returns its value.
  # Raises otherwise.
  def as_bool : Bool
    @raw.as(Bool)
  end

  # Checks that the underlying value is `Bool`, and returns its value.
  # Returns `nil` otherwise.
  def as_bool? : Bool?
    as_bool if @raw.is_a?(Bool)
  end

  # Checks that the underlying value is `Int`, and returns its value as an `Int32`.
  # Raises otherwise.
  def as_i : Int32
    @raw.as(Int).to_i
  end

  # Checks that the underlying value is `Int`, and returns its value as an `Int32`.
  # Returns `nil` otherwise.
  def as_i? : Int32?
    as_i if @raw.is_a?(Int)
  end

  # Checks that the underlying value is `Int`, and returns its value as an `Int64`.
  # Raises otherwise.
  def as_i64 : Int64
    @raw.as(Int).to_i64
  end

  # Checks that the underlying value is `Int`, and returns its value as an `Int64`.
  # Returns `nil` otherwise.
  def as_i64? : Int64?
    as_i64 if @raw.is_a?(Int64)
  end

  # Checks that the underlying value is `Float`, and returns its value as an `Float64`.
  # Raises otherwise.
  def as_f : Float64
    @raw.as(Float).to_f
  end

  # Checks that the underlying value is `Float`, and returns its value as an `Float64`.
  # Returns `nil` otherwise.
  def as_f? : Float64?
    as_f if @raw.is_a?(Float64)
  end

  # Checks that the underlying value is `Float`, and returns its value as an `Float32`.
  # Raises otherwise.
  def as_f32 : Float32
    @raw.as(Float).to_f32
  end

  # Checks that the underlying value is `Float`, and returns its value as an `Float32`.
  # Returns `nil` otherwise.
  def as_f32? : Float32?
    as_f32 if (@raw.is_a?(Float32) || @raw.is_a?(Float64))
  end

  # Checks that the underlying value is `String`, and returns its value.
  # Raises otherwise.
  def as_s : String
    @raw.as(String)
  end

  # Checks that the underlying value is `String`, and returns its value.
  # Returns `nil` otherwise.
  def as_s? : String?
    as_s if @raw.is_a?(String)
  end

  # Checks that the underlying value is `Array`, and returns its value.
  # Raises otherwise.
  def as_a : Array(Type)
    @raw.as(Array)
  end

  # Checks that the underlying value is `Array`, and returns its value.
  # Returns `nil` otherwise.
  def as_a? : Array(Type)?
    as_a if @raw.is_a?(Array(Type))
  end

  # Checks that the underlying value is `Hash`, and returns its value.
  # Raises otherwise.
  def as_h : Hash(String, Type)
    @raw.as(Hash)
  end

  # Checks that the underlying value is `Hash`, and returns its value.
  # Returns `nil` otherwise.
  def as_h? : Hash(String, Type)?
    as_h if @raw.is_a?(Hash(String, Type))
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
  def ==(other : JSON::Any)
    raw == other.raw
  end

  # Returns `true` if the raw object is equal to *other*.
  def ==(other)
    raw == other
  end

  # See `Object#hash(hasher)`
  def_hash raw

  # :nodoc:
  def to_json(json : JSON::Builder)
    raw.to_json(json)
  end
end

class Object
  def ===(other : JSON::Any)
    self === other.raw
  end
end

class Regex
  def ===(other : JSON::Any)
    value = self === other.raw
    $~ = $~
    value
  end
end
