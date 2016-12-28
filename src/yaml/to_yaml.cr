class Object
  def to_yaml(tag : String? = nil, style : LibYAML::Style = nil)
    String.build do |str|
      to_yaml(str, tag, style)
    end
  end

  def to_yaml(io : IO, tag : String? = nil, style : LibYAML::Style = nil)
    YAML::Emitter.new(io) do |emitter|
      emitter.stream do
        emitter.document do
          to_yaml(emitter, tag, style)
        end
      end
    end
  end

  # backward compatability
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::Style = nil)
    to_yaml(emitter)
  end
end

class Hash
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::MappingStyle? = nil)
    emitter.mapping(tag, style) do
      each do |key, value|
        key.to_yaml(emitter)
        value.to_yaml(emitter)
      end
    end
  end
end

class Array
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::SequenceStyle? = nil)
    emitter.sequence(tag, style) do
      each &.to_yaml(emitter)
    end
  end
end

struct Tuple
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::SequenceStyle? = nil)
    emitter.sequence(tag, style) do
      each &.to_yaml(emitter)
    end
  end
end

struct NamedTuple
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::MappingStyle? = nil)
    emitter.mapping(tag, style) do
      {% for key in T.keys %}
        {{key.symbolize}}.to_yaml(emitter)
        self[{{key.symbolize}}].to_yaml(emitter)
      {% end %}
    end
  end
end

class String
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    emitter.scalar(to_s, tag, style)
  end
end

struct Number
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    emitter.scalar(to_s, tag, style)
  end
end

struct Nil
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    emitter.scalar("", tag, style)
  end
end

struct Bool
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    emitter.scalar(to_s, tag, style)
  end
end

struct Set
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::SequenceStyle? = nil)
    emitter.sequence(tag, style) do
      each &.to_yaml(emitter)
    end
  end
end

struct Symbol
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    emitter.scalar(to_s, tag, style)
  end
end

struct Enum
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    emitter.scalar(value.to_s, tag, style)
  end
end

struct Time
  def to_yaml(emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    emitter.scalar(Time::Format::ISO_8601_DATE_TIME.format(self), tag, style)
  end
end

struct Time::Format
  def to_yaml(value : Time, emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    format(value).to_yaml(emitter, tag, style)
  end
end

module Time::EpochConverter
  def self.to_yaml(value : Time, emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    emitter.scalar(value.epoch.to_s, tag, style)
  end
end

module Time::EpochMillisConverter
  def self.to_yaml(value : Time, emitter : YAML::Emitter, tag : String? = nil, style : LibYAML::ScalarStyle? = nil)
    emitter.scalar(value.epoch_ms.to_s, tag, style)
  end
end
