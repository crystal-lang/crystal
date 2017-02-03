class Object
  def to_yaml
    String.build do |io|
      to_yaml(io)
    end
  end

  def to_yaml(io : IO)
    YAML.build(io) do |yaml|
      to_yaml(yaml)
    end
  end
end

class Hash
  def to_yaml(yaml : YAML::Builder)
    yaml.mapping do
      each do |key, value|
        key.to_yaml(yaml)
        value.to_yaml(yaml)
      end
    end
  end
end

class Array
  def to_yaml(yaml : YAML::Builder)
    yaml.sequence do
      each &.to_yaml(yaml)
    end
  end
end

struct Tuple
  def to_yaml(yaml : YAML::Builder)
    yaml.sequence do
      each &.to_yaml(yaml)
    end
  end
end

struct NamedTuple
  def to_yaml(yaml : YAML::Builder)
    yaml.mapping do
      {% for key in T.keys %}
        {{key.symbolize}}.to_yaml(yaml)
        self[{{key.symbolize}}].to_yaml(yaml)
      {% end %}
    end
  end
end

class String
  def to_yaml(yaml : YAML::Builder)
    yaml.scalar self
  end
end

struct Number
  def to_yaml(yaml : YAML::Builder)
    yaml.scalar self
  end
end

struct Nil
  def to_yaml(yaml : YAML::Builder)
    yaml.scalar ""
  end
end

struct Bool
  def to_yaml(yaml : YAML::Builder)
    yaml.scalar self
  end
end

struct Set
  def to_yaml(yaml : YAML::Builder)
    yaml.sequence do
      each &.to_yaml(yaml)
    end
  end
end

struct Symbol
  def to_yaml(yaml : YAML::Builder)
    yaml.scalar self
  end
end

struct Enum
  def to_yaml(yaml : YAML::Builder)
    yaml.scalar value
  end
end

struct Time
  def to_yaml(yaml : YAML::Builder)
    yaml.scalar Time::Format::ISO_8601_DATE_TIME.format(self)
  end
end

struct Time::Format
  def to_yaml(value : Time, yaml : YAML::Builder)
    format(value).to_yaml(yaml)
  end
end

module Time::EpochConverter
  def self.to_yaml(value : Time, yaml : YAML::Builder)
    yaml.scalar value.epoch
  end
end

module Time::EpochMillisConverter
  def self.to_yaml(value : Time, yaml : YAML::Builder)
    yaml.scalar value.epoch_ms
  end
end
