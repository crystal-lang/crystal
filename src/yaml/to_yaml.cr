class Object
  def to_yaml
    String.build do |str|
      to_yaml(str)
    end
  end

  def to_yaml(io : IO)
    YAML::Emitter.new(io) do |emitter|
      emitter.stream do
        emitter.document do
          to_yaml(emitter)
        end
      end
    end
  end
end

class Hash
  def to_yaml(emitter : YAML::Emitter)
    emitter.mapping do
      each do |key, value|
        key.to_yaml(emitter)
        value.to_yaml(emitter)
      end
    end
  end
end

class Array
  def to_yaml(emitter : YAML::Emitter)
    emitter.sequence do
      each &.to_yaml(emitter)
    end
  end
end

struct Tuple
  def to_yaml(emitter : YAML::Emitter)
    emitter.sequence do
      each &.to_yaml(emitter)
    end
  end
end

struct NamedTuple
  def to_yaml(emitter : YAML::Emitter)
    emitter.mapping do
      {% for key in T.keys %}
        {{key.symbolize}}.to_yaml(emitter)
        self[{{key.symbolize}}].to_yaml(emitter)
      {% end %}
    end
  end
end

class String
  def to_yaml(emitter : YAML::Emitter)
    emitter << self
  end
end

struct Number
  def to_yaml(emitter : YAML::Emitter)
    emitter << self
  end
end

struct Nil
  def to_yaml(emitter : YAML::Emitter)
    emitter << ""
  end
end

struct Bool
  def to_yaml(emitter : YAML::Emitter)
    emitter << self
  end
end

struct Set
  def to_yaml(emitter : YAML::Emitter)
    emitter.sequence do
      each &.to_yaml(emitter)
    end
  end
end

struct Symbol
  def to_yaml(emitter : YAML::Emitter)
    emitter << self
  end
end

struct Enum
  def to_yaml(emitter : YAML::Emitter)
    emitter << value
  end
end

struct Time
  def to_yaml(emitter : YAML::Emitter)
    emitter << Time::Format::ISO_8601_DATE_TIME.format(self)
  end
end

struct Time::Format
  def to_yaml(value : Time, emitter : YAML::Emitter)
    format(value).to_yaml(emitter)
  end
end

module Time::EpochConverter
  def self.to_yaml(value : Time, emitter : YAML::Emitter)
    emitter << value.epoch
  end
end

module Time::EpochMillisConverter
  def self.to_yaml(value : Time, emitter : YAML::Emitter)
    emitter << value.epoch_ms
  end
end
