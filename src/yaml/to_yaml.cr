class Object
  def to_yaml : String
    String.build do |io|
      to_yaml(io)
    end
  end

  def to_yaml(io : IO) : Nil
    # First convert the object to an in-memory tree.
    # With this, `to_yaml` will be invoked just once
    # on every object and we can use anchors and aliases
    # for objects that are serialized multiple times.
    nodes_builder = YAML::Nodes::Builder.new
    to_yaml(nodes_builder)

    # Then we convert the tree to YAML.
    YAML.build(io) do |builder|
      nodes_builder.document.to_yaml(builder)
    end
  end
end

class Hash
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.mapping(reference: self) do
      each do |key, value|
        key.to_yaml(yaml)
        value.to_yaml(yaml)
      end
    end
  end
end

class Array
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.sequence(reference: self) do
      each &.to_yaml(yaml)
    end
  end
end

module Iterator(T)
  # Converts the content of an iterator to YAML.
  # The conversion is done in a lazy way.
  # In contrast to `Iterator#to_json` this operation requires memory for the
  # for the complete YAML document
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.sequence(reference: self) do
      each &.to_yaml(yaml)
    end
  end
end

struct Tuple
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.sequence do
      each &.to_yaml(yaml)
    end
  end
end

struct NamedTuple
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.mapping do
      {% for key in T.keys %}
        {{ key.symbolize }}.to_yaml(yaml)
        self[{{ key.symbolize }}].to_yaml(yaml)
      {% end %}
    end
  end
end

class String
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    if YAML::Schema::Core.reserved_string?(self)
      yaml.scalar self, style: YAML::ScalarStyle::DOUBLE_QUOTED
    else
      yaml.scalar self
    end
  end
end

struct Path
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    @name.to_yaml(yaml)
  end
end

struct Number
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.scalar self.to_s
  end
end

struct Float
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    infinite = self.infinite?
    if infinite == 1
      yaml.scalar(".inf")
    elsif infinite == -1
      yaml.scalar("-.inf")
    elsif nan?
      yaml.scalar(".nan")
    else
      yaml.scalar self.to_s
    end
  end
end

struct Nil
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.scalar ""
  end
end

struct Bool
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.scalar self
  end
end

struct Set
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.sequence do
      each &.to_yaml(yaml)
    end
  end
end

struct Symbol
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.scalar self
  end
end

struct Enum
  # Serializes this enum member by name.
  #
  # For non-flags enums, the serialization is a YAML string. The value is the
  # member name (see `#to_s`) transformed with `String#underscore`.
  #
  # ```
  # enum Stages
  #   INITIAL
  #   SECOND_STAGE
  # end
  #
  # Stages::INITIAL.to_yaml      # => %(--- initial\n)
  # Stages::SECOND_STAGE.to_yaml # => %(--- second_stage\n)
  # ```
  #
  # For flags enums, the serialization is a YAML sequence including every flagged
  # member individually serialized in the same way as a member of a non-flags enum.
  # `None` is serialized as an empty sequence, `All` as a sequence containing
  # all members.
  #
  # ```
  # @[Flags]
  # enum Sides
  #   LEFT
  #   RIGHT
  # end
  #
  # Sides::LEFT.to_yaml                  # => %(--- [left]\n)
  # (Sides::LEFT | Sides::RIGHT).to_yaml # => %(--- [left, right]\n)
  # Sides::All.to_yaml                   # => %(--- [left, right]\n)
  # Sides::None.to_yaml                  # => %(--- []\n)
  # ```
  #
  # `ValueConverter.to_yaml` offers a different serialization strategy based on the
  # member value.
  def to_yaml(yaml : YAML::Nodes::Builder)
    {% if @type.annotation(Flags) %}
      yaml.sequence(style: :flow) do
        each do |member, _value|
          member.to_s.underscore.to_yaml(yaml)
        end
      end
    {% else %}
      to_s.underscore.to_yaml(yaml)
    {% end %}
  end
end

module Enum::ValueConverter(T)
  def self.to_yaml(value : T)
    String.build do |io|
      to_yaml(value, io)
    end
  end

  def self.to_yaml(value : T, io : IO)
    nodes_builder = YAML::Nodes::Builder.new
    to_yaml(value, nodes_builder)

    # Then we convert the tree to YAML.
    YAML.build(io) do |builder|
      nodes_builder.document.to_yaml(builder)
    end
  end

  # Serializes enum member *member* by value.
  #
  # For both flags enums and non-flags enums, the value of the enum member is
  # used for serialization.
  #
  # ```
  # enum Stages
  #   INITIAL
  #   SECOND_STAGE
  # end
  #
  # Enum::ValueConverter.to_yaml(Stages::INITIAL)      # => %(--- 0\n)
  # Enum::ValueConverter.to_yaml(Stages::SECOND_STAGE) # => %(--- 1\n)
  #
  # @[Flags]
  # enum Sides
  #   LEFT
  #   RIGHT
  # end
  #
  # Enum::ValueConverter.to_yaml(Sides::LEFT)                # => %(--- 1\n)
  # Enum::ValueConverter.to_yaml(Sides::LEFT | Sides::RIGHT) # => %(--- 3\n)
  # Enum::ValueConverter.to_yaml(Sides::All)                 # => %(--- 3\n)
  # Enum::ValueConverter.to_yaml(Sides::None)                # => %(--- 0\n)
  # ```
  #
  # `Enum#to_yaml` offers a different serialization strategy based on the member
  # name.
  def self.to_yaml(member : T, yaml : YAML::Nodes::Builder)
    yaml.scalar(member.value)
  end
end

struct Time
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.scalar Time::Format::YAML_DATE.format(self)
  end
end

class Time::Location
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    yaml.scalar to_s
  end
end

struct Time::Format
  def to_yaml(value : Time, yaml : YAML::Nodes::Builder) : Nil
    yaml.scalar format(value)
  end
end

module Time::EpochConverter
  def self.to_yaml(value : Time, yaml : YAML::Nodes::Builder) : Nil
    yaml.scalar value.to_unix
  end
end

module Time::EpochMillisConverter
  def self.to_yaml(value : Time, yaml : YAML::Nodes::Builder) : Nil
    yaml.scalar value.to_unix_ms
  end
end

# Converter to be used with `YAML::Serializable`
# to serialize the elements of an `Array(T)` with the custom converter.
#
# ```
# require "yaml"
#
# class Timestamp
#   include YAML::Serializable
#
#   @[YAML::Field(converter: YAML::ArrayConverter(Time::EpochConverter))]
#   property values : Array(Time)
# end
#
# timestamp = Timestamp.from_yaml(%({"values":[1459859781,1567628762]}))
# timestamp.values  # => [2016-04-05 12:36:21Z, 2019-09-04 20:26:02Z]
# timestamp.to_yaml # => "---\nvalues:\n- 1459859781\n- 1567628762\n"
# ```
#
# `YAML::ArrayConverter.new` should be used if the nested converter is also an
# instance instead of a type.
#
# ```
# require "yaml"
#
# class Timestamp
#   include YAML::Serializable
#
#   @[YAML::Field(converter: YAML::ArrayConverter.new(Time::Format.new("%b %-d, %Y")))]
#   property values : Array(Time)
# end
#
# timestamp = Timestamp.from_yaml(%({"values":["Apr 5, 2016","Sep 4, 2019"]}))
# timestamp.values  # => [2016-04-05 00:00:00Z, 2019-09-04 00:00:00Z]
# timestamp.to_yaml # => "---\nvalues:\n- Apr 5, 2016\n- Sep 4, 2019\n"
# ```
#
# This implies that `YAML::ArrayConverter(T)` and
# `YAML::ArrayConverter(T.class).new(T)` perform the same serializations.
module YAML::ArrayConverter(Converter)
  private struct WithInstance(T)
    def initialize(@converter : T)
    end

    def to_yaml(values : Array, yaml : YAML::Nodes::Builder)
      yaml.sequence(reference: self) do
        values.each do |value|
          @converter.to_yaml(value, yaml)
        end
      end
    end
  end

  def self.new(converter : Converter)
    WithInstance.new(converter)
  end

  def self.to_yaml(values : Array, yaml : YAML::Nodes::Builder)
    WithInstance.new(Converter).to_yaml(values, yaml)
  end
end

struct Slice
  def to_yaml(yaml : YAML::Nodes::Builder) : Nil
    {% if T != UInt8 %}
      {% raise "Can only serialize Slice(UInt8), not #{@type}}" %}
    {% end %}

    yaml.scalar Base64.encode(self), tag: "tag:yaml.org,2002:binary"
  end
end
