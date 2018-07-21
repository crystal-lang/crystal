require "../any"

# `YAML::Any` is a convenient wrapper around all possible YAML core types
# (`YAML::Any::Type`) and can be used for traversing dynamic or
# unknown YAML structures.
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
struct YAML::Any < ::Any
  # All valid YAML core schema types.
  alias Type = Nil | Bool | Int64 | Float64 | String | Time | Bytes | Array(Any) | Hash(Any, Any) | Set(Any)

  def self.new(ctx : YAML::ParseContext, node : YAML::Nodes::Node)
    anchors = {} of String => Any
    convert(node, anchors)
  end

  private def self.convert(node, anchors)
    case node
    when YAML::Nodes::Scalar
      new YAML::Schema::Core.parse_scalar(node.value)
    when YAML::Nodes::Sequence
      ary = [] of Any

      if anchor = node.anchor
        anchors[anchor] = Any.new(ary)
      end

      node.each do |value|
        ary << convert(value, anchors)
      end

      new ary
    when YAML::Nodes::Mapping
      hash = {} of Any => Any

      if anchor = node.anchor
        anchors[anchor] = Any.new(hash)
      end

      node.each do |key, value|
        hash[convert(key, anchors)] = convert(value, anchors)
      end

      new hash
    when YAML::Nodes::Alias
      anchors[node.anchor]
    else
      raise "Unknown node: #{node.class}"
    end
  end

  # Returns the raw underlying value, a `Type`.
  getter raw : Type

  # Creates a `Any` that wraps the given `Type`.
  def initialize(@raw : Type)
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
  def as_h : Hash(Any, Any)
    @raw.as(Hash)
  end

  # Checks that the underlying value is `Hash`, and returns its value.
  # Returns `nil` otherwise.
  def as_h? : Hash(Any, Any)?
    @raw.as?(Hash)
  end

  # :nodoc:
  def to_yaml(io)
    raw.to_yaml(io)
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

any_classes "YAML"
