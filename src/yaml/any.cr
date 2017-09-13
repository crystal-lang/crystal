# `YAML::Any` is a convenient wrapper around all possible YAML types (`YAML::Type`)
# and can be used for traversing dynamic or unknown YAML structures.
#
# ```
# require "yaml"
#
# data = YAML.parse <<-END
#          ---
#          foo:
#            bar:
#              baz:
#                - qux
#                - fox
#          END
# data["foo"]["bar"]["baz"][0].as_s # => "qux"
# data["foo"]["bar"]["baz"].as_a    # => ["qux", "fox"]
# ```
#
# Note that methods used to traverse a YAML structure, `#[]`, `#[]?` and `#each`,
# always return a `YAML::Any` to allow further traversal. To convert them to `String`,
# `Array`, etc., use the `as_` methods, such as `#as_s`, `#as_a`, which perform
# a type check against the raw underlying value. This means that invoking `#as_s`
# when the underlying value is not a `String` will raise: the value won't automatically
# be converted (parsed) to a `String`.
struct YAML::Any
  include Enumerable(self)

  # Reads a `YAML::Any` value from the given pull parser.
  def self.new(pull : YAML::PullParser)
    case pull.kind
    when .scalar?
      new pull.read_scalar
    when .sequence_start?
      ary = [] of Type
      pull.read_sequence do
        while pull.kind != YAML::EventKind::SEQUENCE_END
          ary << new(pull).raw
        end
      end
      new ary
    when .mapping_start?
      hash = {} of Type => Type
      pull.read_mapping do
        while pull.kind != YAML::EventKind::MAPPING_END
          hash[new(pull).raw] = new(pull).raw
        end
      end
      new hash
    else
      raise "Unknown pull kind: #{pull.kind}"
    end
  end

  # Returns the raw underlying value, a `YAML::Type`.
  getter raw : YAML::Type

  # Creates a `YAML::Any` that wraps the given `YAML::Type`.
  def initialize(@raw : YAML::Type)
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

  # Assumes the underlying value is an `Array` and returns the element
  # at the given *index*.
  #
  # Raises if the underlying value is not an `Array`.
  def [](index : Int) : YAML::Any
    case object = @raw
    when Array
      Any.new object[index]
    else
      raise "Expected Array for #[](index : Int), not #{object.class}"
    end
  end

  # Assumes the underlying value is an `Array` and returns the element
  # at the given *index*, or `nil` if out of bounds.
  #
  # Raises if the underlying value is not an `Array`.
  def []?(index : Int) : YAML::Any?
    case object = @raw
    when Array
      value = object[index]?
      value ? Any.new(value) : nil
    else
      raise "Expected Array for #[]?(index : Int), not #{object.class}"
    end
  end

  # Assumes the underlying value is a `Hash` and returns the element
  # with the given *key*.
  #
  # Raises if the underlying value is not a `Hash`.
  def [](key : String) : YAML::Any
    case object = @raw
    when Hash
      Any.new object[key]
    else
      raise "Expected Hash for #[](key : String), not #{object.class}"
    end
  end

  # Assumes the underlying value is a `Hash` and returns the element
  # with the given *key*, or `nil` if the key is not present.
  #
  # Raises if the underlying value is not a `Hash`.
  def []?(key : String) : YAML::Any?
    case object = @raw
    when Hash
      value = object[key]?
      value ? Any.new(value) : nil
    else
      raise "Expected Hash for #[]?(key : String), not #{object.class}"
    end
  end

  # Assumes the underlying value is an `Array` or `Hash` and yields each
  # of the elements or key/values, always as `YAML::Any`.
  #
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
  def as_h : Hash(Type, Type)
    @raw.as(Hash)
  end

  # Checks that the underlying value is `Hash`, and returns its value.
  # Returns `nil` otherwise.
  def as_h? : Hash(Type, Type)?
    as_h if @raw.is_a?(Hash(Type, Type))
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
  def to_yaml(io)
    raw.to_yaml(io)
  end
end

class Object
  def ===(other : YAML::Any)
    self === other.raw
  end
end

class Regex
  def ===(other : YAML::Any)
    value = self === other.raw
    $~ = $~
    value
  end
end
