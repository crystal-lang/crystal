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

struct Number
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.scalar self.to_s
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
  def to_yaml(yaml : YAML::Nodes::Builder)
    yaml.scalar value
  end
end

struct Time
  def to_yaml(yaml : YAML::Nodes::Builder)
    if kind.utc? || kind.unspecified?
      if hour == 0 && minute == 0 && second == 0 && millisecond == 0
        yaml.scalar Time::Format.new("%F").format(self)
      elsif millisecond == 0
        yaml.scalar Time::Format.new("%F %X").format(self)
      else
        yaml.scalar Time::Format.new("%F %X.%L").format(self)
      end
    elsif millisecond == 0
      yaml.scalar Time::Format.new("%F %X %:z").format(self)
    else
      yaml.scalar Time::Format.new("%F %X.%L %:z").format(self)
    end
  end
end

struct Time::Format
  def to_yaml(value : Time, yaml : YAML::Nodes::Builder)
    yaml.scalar format(value)
  end
end

module Time::EpochConverter
  def self.to_yaml(value : Time, yaml : YAML::Nodes::Builder)
    yaml.scalar value.epoch
  end
end

module Time::EpochMillisConverter
  def self.to_yaml(value : Time, yaml : YAML::Nodes::Builder)
    yaml.scalar value.epoch_ms
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
