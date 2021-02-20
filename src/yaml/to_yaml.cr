class Object
  def to_yaml
    String.build do |io|
      to_yaml(io)
    end
  end

  def to_yaml(io : IO)
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
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.mapping(reference: self) do
      each do |key, value|
        key.to_yaml(yaml)
        value.to_yaml(yaml)
      end
    end
  end
end

class Array
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.sequence(reference: self) do
      each &.to_yaml(yaml)
    end
  end
end

struct Tuple
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.sequence do
      each &.to_yaml(yaml)
    end
  end
end

struct NamedTuple
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.mapping do
      {% for key in T.keys %}
        {{key.symbolize}}.to_yaml(yaml)
        self[{{key.symbolize}}].to_yaml(yaml)
      {% end %}
    end
  end
end

class String
  def to_yaml(yaml : YAML::Nodes::Builder)
    if YAML::Schema::Core.reserved_string?(self)
      yaml.scalar self, style: YAML::ScalarStyle::DOUBLE_QUOTED
    else
      yaml.scalar self
    end
  end
end

struct Path
  def to_yaml(yaml : YAML::Nodes::Builder)
    @name.to_yaml(yaml)
  end
end

struct Number
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.scalar self.to_s
  end
end

struct Float
  def to_yaml(yaml : YAML::Nodes::Builder)
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
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.scalar ""
  end
end

struct Bool
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.scalar self
  end
end

struct Set
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.sequence do
      each &.to_yaml(yaml)
    end
  end
end

struct Symbol
  def to_yaml(yaml : YAML::Nodes::Builder)
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
  # Sides::LEFT.to_yaml                  # => %(--- ["left"]\n)
  # (Sides::LEFT | Sides::RIGHT).to_yaml # => %(--- ["left", "right"]\n)
  # Sides::All.to_yaml                   # => %(--- ["left", "right"]\n)
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
  # Enum::ValueConverter.to_yaml(Stages::INITIAL)      # => %(0)
  # Enum::ValueConverter.to_yaml(Stages::SECOND_STAGE) # => %(1)
  #
  # @[Flags]
  # enum Sides
  #   LEFT
  #   RIGHT
  # end
  #
  # Enum::ValueConverter.to_yaml(Sides::LEFT)                # => %(1)
  # Enum::ValueConverter.to_yaml(Sides::LEFT | Sides::RIGHT) # => %(3)
  # Enum::ValueConverter.to_yaml(Sides::All)                 # => %(3)
  # Enum::ValueConverter.to_yaml(Sides::None)                # => %(0)
  # ```
  #
  # `Enum#to_yaml` offers a different serialization strategy based on the member
  # name.
  def self.to_yaml(member : T, yaml : YAML::Nodes::Builder)
    yaml.scalar(member.value)
  end
end

struct Time
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.scalar Time::Format::YAML_DATE.format(self)
  end
end

struct Time::Format
  def to_yaml(value : Time, yaml : YAML::Nodes::Builder)
    yaml.scalar format(value)
  end
end

module Time::EpochConverter
  def self.to_yaml(value : Time, yaml : YAML::Nodes::Builder)
    yaml.scalar value.to_unix
  end
end

module Time::EpochMillisConverter
  def self.to_yaml(value : Time, yaml : YAML::Nodes::Builder)
    yaml.scalar value.to_unix_ms
  end
end

# Converter to be used with `YAML::Serializable`
# to serialize the `Array(T)` elements with the custom converter.
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
# timestamp.values  # => [2016-04-05 12:36:21 UTC, 2019-09-04 20:26:02 UTC]
# timestamp.to_yaml # => ---\nvalues:\n- 1459859781\n- 1567628762\n
# ```
module YAML::ArrayConverter(Converter)
  def self.to_yaml(values : Array, yaml : YAML::Nodes::Builder)
    yaml.sequence(reference: self) do
      values.each do |value|
        Converter.to_yaml(value, yaml)
      end
    end
  end
end

struct Slice
  def to_yaml(yaml : YAML::Nodes::Builder)
    {% if T != UInt8 %}
      {% raise "Can only serialize Slice(UInt8), not #{@type}}" %}
    {% end %}

    yaml.scalar Base64.encode(self), tag: "tag:yaml.org,2002:binary"
  end
end
