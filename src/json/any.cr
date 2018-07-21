require "../any"

# `JSON::Any` is a convenient wrapper around all possible JSON types (`JSON::Any::Type`)
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
struct JSON::Any < ::Any
  # All possible JSON types.
  alias Type = Nil | Bool | Int64 | Float64 | String | Array(Any) | Hash(String, Any)

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
      ary = [] of JSON::Any
      pull.read_array do
        ary << new(pull)
      end
      new ary
    when :begin_object
      hash = {} of String => JSON::Any
      pull.read_object do |key|
        hash[key] = new(pull)
      end
      new hash
    else
      raise "Unknown pull kind: #{pull.kind}"
    end
  end

  # Returns the raw underlying value.
  getter raw : Type

  # Creates a `JSON::Any` that wraps the given value.
  def initialize(@raw : Type)
  end

  # Assumes the underlying value is an `Array` and returns the element
  # at the given index.
  # Raises if the underlying value is not an `Array`.
  def [](index : Int) : JSON::Any
    case object = @raw
    when Array
      object[index]
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
      object[index]?
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
      object[key]
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
      object[key]?
    else
      raise "Expected Hash for #[]?(key : String), not #{object.class}"
    end
  end

  # Checks that the underlying value is `Array`, and returns its value.
  # Raises otherwise.
  def as_a : Array(Any)
    @raw.as(Array)
  end

  # Checks that the underlying value is `Array`, and returns its value.
  # Returns `nil` otherwise.
  def as_a? : Array(Any)?
    @raw.as?(Array)
  end

  # Checks that the underlying value is `Hash`, and returns its value.
  # Raises otherwise.
  def as_h : Hash(String, Any)
    @raw.as(Hash)
  end

  # Checks that the underlying value is `Hash`, and returns its value.
  # Returns `nil` otherwise.
  def as_h? : Hash(String, Any)?
    @raw.as?(Hash)
  end

  # :nodoc:
  def to_json(json : JSON::Builder)
    raw.to_json(json)
  end

  # Returns a new Any instance with the `raw` value `dup`ed.
  def dup
    Any.new(raw.dup)
  end

  # Returns a new Any instance with the `raw` value `clone`ed.
  def clone
    Any.new(raw.clone)
  end
end

any_classes "JSON"
