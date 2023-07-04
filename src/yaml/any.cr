# `YAML::Any` is a convenient wrapper around all possible YAML core types
# (`YAML::Any::Type`) and can be used for traversing dynamic or
# unknown YAML structures.
#
# ```
# require "yaml"
#
# data = YAML.parse <<-YAML
#          ---
#          foo:
#            bar:
#              baz:
#                - qux
#                - fox
#          YAML
# data["foo"]["bar"]["baz"][0].as_s # => "qux"
# data["foo"]["bar"]["baz"].as_a    # => ["qux", "fox"]
# ```
#
# Note that methods used to traverse a YAML structure, `#[]`, `#[]?` and `#each`,
# always return a `YAML::Any` to allow further traversal. To convert them to `String`,
# `Array`, etc., use the `as_` methods, such as `#as_s`, `#as_a`, which perform
# a type check against the raw underlying value. This means that invoking `#as_s`
# when the underlying value is not a `String` will raise: the value won't automatically
# be converted (parsed) to a `String`. There are also nil-able variants (`#as_i?`, `#as_s?`, ...),
# which return `nil` when the underlying value type won't match.
struct YAML::Any
  # All valid YAML core schema types.
  alias Type = Nil | Bool | Int64 | Float64 | String | Time | Bytes | Array(YAML::Any) | Hash(YAML::Any, YAML::Any) | Set(YAML::Any)

  def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    case node
    when YAML::Nodes::Scalar
      new YAML::Schema::Core.parse_scalar(node)
    when YAML::Nodes::Sequence
      ary = [] of YAML::Any

      node.each do |value|
        ary << new(ctx, value)
      end

      new ary
    when YAML::Nodes::Mapping
      hash = {} of YAML::Any => YAML::Any

      node.each do |key, value|
        hash[new(ctx, key)] = new(ctx, value)
      end

      new hash
    when YAML::Nodes::Alias
      if value = node.value
        new(ctx, value)
      else
        raise "YAML::Nodes::Alias misses anchor value"
      end
    else
      raise "Unknown node: #{node.class}"
    end
  end

  # Returns the raw underlying value, a `Type`.
  getter raw : Type

  # Creates a `YAML::Any` that wraps the given `Type`.
  def initialize(@raw : Type)
  end

  # :ditto:
  def self.new(raw : Int)
    # FIXME: Workaround for https://github.com/crystal-lang/crystal/issues/11645
    new(raw.to_i64)
  end

  # :ditto:
  def self.new(raw : Float)
    # FIXME: Workaround for https://github.com/crystal-lang/crystal/issues/11645
    new(raw.to_f64)
  end

  # Assumes the underlying value is an `Array` or `Hash` and returns its size.
  #
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

  # Assumes the underlying value is an `Array` or `Hash`
  # and returns the element at the given *index_or_key*.
  #
  # Raises if the underlying value is not an `Array` nor a `Hash`.
  def [](index_or_key) : YAML::Any
    case object = @raw
    when Array
      if index_or_key.is_a?(Int)
        object[index_or_key]
      else
        raise "Expected int key for Array#[], not #{object.class}"
      end
    when Hash
      object[index_or_key]
    else
      raise "Expected Array or Hash, not #{object.class}"
    end
  end

  # Assumes the underlying value is an `Array` or `Hash` and returns the element
  # at the given *index_or_key*, or `nil` if out of bounds or the key is missing.
  #
  # Raises if the underlying value is not an `Array` nor a `Hash`.
  def []?(index_or_key) : YAML::Any?
    case object = @raw
    when Array
      if index_or_key.is_a?(Int)
        object[index_or_key]?
      else
        nil
      end
    when Hash
      object[index_or_key]?
    else
      raise "Expected Array or Hash, not #{object.class}"
    end
  end

  # Traverses the depth of a structure and returns the value.
  # Returns `nil` if not found.
  def dig?(index_or_key, *subkeys) : YAML::Any?
    self[index_or_key]?.try &.dig?(*subkeys)
  end

  # :nodoc:
  def dig?(index_or_key) : YAML::Any?
    case @raw
    when Hash, Array
      self[index_or_key]?
    else
      nil
    end
  end

  # Traverses the depth of a structure and returns the value, otherwise raises.
  def dig(index_or_key, *subkeys) : YAML::Any
    self[index_or_key].dig(*subkeys)
  end

  # :nodoc:
  def dig(index_or_key) : YAML::Any
    self[index_or_key]
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

  # Checks that the underlying value is `Int64`, and returns its value as `Int32`.
  # Raises otherwise.
  def as_i : Int32
    @raw.as(Int64).to_i
  end

  # Checks that the underlying value is `Int64`, and returns its value as `Int32`.
  # Returns `nil` otherwise.
  def as_i? : Int32?
    as_i if @raw.is_a?(Int)
  end

  # Checks that the underlying value is `Float` (or `Int`), and returns its value.
  # Raises otherwise.
  def as_f : Float64
    case raw = @raw
    when Int
      raw.to_f
    else
      raw.as(Float64)
    end
  end

  # Checks that the underlying value is `Float` (or `Int`), and returns its value.
  # Returns `nil` otherwise.
  def as_f? : Float64?
    case raw = @raw
    when Int
      raw.to_f
    else
      raw.as?(Float64)
    end
  end

  # Checks that the underlying value is `Float` (or `Int`), and returns its value as an `Float32`.
  # Raises otherwise.
  def as_f32 : Float32
    case raw = @raw
    when Int
      raw.to_f32
    else
      raw.as(Float).to_f32
    end
  end

  # Checks that the underlying value is `Float` (or `Int`), and returns its value as an `Float32`.
  # Returns `nil` otherwise.
  def as_f32? : Float32?
    case raw = @raw
    when Int
      raw.to_f32
    when Float
      raw.to_f32
    else
      nil
    end
  end

  # Checks that the underlying value is `Time`, and returns its value.
  # Raises otherwise.
  def as_time : Time
    @raw.as(Time)
  end

  # Checks that the underlying value is `Time`, and returns its value.
  # Returns `nil` otherwise.
  def as_time? : Time?
    @raw.as?(Time)
  end

  # Checks that the underlying value is `Array`, and returns its value.
  # Raises otherwise.
  def as_a : Array(YAML::Any)
    @raw.as(Array)
  end

  # Checks that the underlying value is `Array`, and returns its value.
  # Returns `nil` otherwise.
  def as_a? : Array(YAML::Any)?
    @raw.as?(Array)
  end

  # Checks that the underlying value is `Hash`, and returns its value.
  # Raises otherwise.
  def as_h : Hash(YAML::Any, YAML::Any)
    @raw.as(Hash)
  end

  # Checks that the underlying value is `Hash`, and returns its value.
  # Returns `nil` otherwise.
  def as_h? : Hash(YAML::Any, YAML::Any)?
    @raw.as?(Hash)
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

  def inspect(io : IO) : Nil
    @raw.inspect(io)
  end

  def to_s(io : IO) : Nil
    @raw.to_s(io)
  end

  # :nodoc:
  def pretty_print(pp)
    @raw.pretty_print(pp)
  end

  # Returns `true` if both `self` and *other*'s raw object are equal.
  def ==(other : YAML::Any)
    raw == other.raw
  end

  # Returns `true` if the raw object is equal to *other*.
  def ==(other)
    raw == other
  end

  # See `Object#hash(hasher)`
  def_hash raw

  # :nodoc:
  def to_yaml(io) : Nil
    raw.to_yaml(io)
  end

  def to_json(builder : JSON::Builder) : Nil
    if (raw = self.raw).is_a?(Slice)
      raise "Can't serialize #{raw.class} to JSON"
    else
      raw.to_json(builder)
    end
  end

  # Returns a new YAML::Any instance with the `raw` value `dup`ed.
  def dup
    YAML::Any.new(raw.dup)
  end

  # Returns a new YAML::Any instance with the `raw` value `clone`ed.
  def clone
    YAML::Any.new(raw.clone)
  end

  # Forwards `to_json_object_key` to `raw` if it responds to that method,
  # raises `JSON::Error` otherwise.
  def to_json_object_key : String
    raw = @raw
    if raw.responds_to?(:to_json_object_key)
      raw.to_json_object_key
    else
      raise JSON::Error.new("Can't convert #{raw.class} to a JSON object key")
    end
  end
end

class Object
  def ===(other : YAML::Any)
    self === other.raw
  end
end

struct Value
  def ==(other : YAML::Any)
    self == other.raw
  end
end

class Reference
  def ==(other : YAML::Any)
    self == other.raw
  end
end

class Array
  def ==(other : YAML::Any)
    self == other.raw
  end
end

class Hash
  def ==(other : YAML::Any)
    self == other.raw
  end
end

class Regex
  def ===(other : YAML::Any)
    value = self === other.raw
    $~ = $~
    value
  end
end
