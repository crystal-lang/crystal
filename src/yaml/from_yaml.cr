def Object.from_yaml(string_or_io) : self
  YAML::PullParser.new(string_or_io) do |parser|
    parser.read_stream do
      parser.read_document do
        new parser
      end
    end
  end
end

def Array.from_yaml(string_or_io)
  YAML::PullParser.new(string_or_io) do |parser|
    parser.read_stream do
      parser.read_document do
        new(parser) do |element|
          yield element
        end
      end
    end
  end
end

def Nil.new(pull : YAML::PullParser)
  location = pull.location
  value = pull.read_plain_scalar
  if YAML::NULL_VALUES.includes? value
    nil
  else
    raise YAML::ParseException.new("Expected null, not '#{value}'", *location)
  end
end

def Bool.new(pull : YAML::PullParser)
  location = pull.location
  value = pull.read_plain_scalar
  if YAML::TRUE_VALUES.includes? value
    true
  elsif YAML::FALSE_VALUES.includes? value
    false
  else
    raise YAML::ParseException.new("Expected boolean, not '#{value}'", *location)
  end
end

{% for type in %w(Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64) %}
  def {{type.id}}.new(pull : YAML::PullParser)
    location = pull.location
    value = pull.read_plain_scalar
    begin
      value.to_{{type.gsub(/^(U|I)I?nt/, "\\1").downcase.id}}(prefix: true, underscore: true)
    rescue ex
      raise YAML::ParseException.new(ex.message.not_nil!, *location)
    end
  end
{% end %}

{% for type in %w(Float32 Float64) %}
  def {{type.id}}.new(pull : YAML::PullParser)
    location = pull.location
    value = pull.read_plain_scalar
    if YAML::INFINITY_VALUES.includes? value.lchop('+')
      INFINITY
    elsif value[0]? == '-' && YAML::INFINITY_VALUES.includes?(value.lchop('-'))
      -INFINITY
    elsif YAML::NAN_VALUES.includes? value
      NAN
    else
      begin
        value.to_f{{type.gsub(/^Float/, "").id}}
      rescue ex
        raise YAML::ParseException.new(ex.message.not_nil!, *location)
      end
    end
  end
{% end %}

# TODO: Implement a Time parser that supports all the YAML formats
def Time.new(pull : YAML::PullParser)
  location = pull.location
  begin
    value = pull.read_plain_scalar
    Time::Format::ISO_8601_DATE_TIME.parse(value)
  rescue ex : Time::Format::Error
    raise YAML::ParseException.new("Could not parse time from '#{value}'", *location)
  end
end

def String.new(pull : YAML::PullParser)
  location = pull.location
  return pull.read_scalar unless pull.data.scalar.style == LibYAML::ScalarStyle::PLAIN
  pull.read_plain_scalar.tap do |value|
    reserved = YAML::NULL_VALUES.includes?(value) ||
               YAML::BOOL_VALUES.includes?(value) ||
               YAML::INFINITY_VALUES.includes?(value.lchop('+')) ||
               YAML::INFINITY_VALUES.includes?(value.lchop('-')) ||
               YAML::NAN_VALUES.includes?(value) ||
               value.to_i64?(underscore: true, prefix: true) ||
               value.to_f64? ||
               begin
                 Time::Format::ISO_8601_DATE_TIME.parse(value)
               rescue Time::Format::Error
               end

    raise YAML::ParseException.new("Expected string, not time", *location) if reserved
  end
end

def Array.new(pull : YAML::PullParser)
  ary = new
  new(pull) do |element|
    ary << element
  end
  ary
end

def Array.new(pull : YAML::PullParser)
  pull.read_sequence_start
  while pull.kind != YAML::EventKind::SEQUENCE_END
    yield T.new(pull)
  end
  pull.read_next
end

def Hash.new(pull : YAML::PullParser)
  hash = new
  new(pull) do |key, value|
    hash[key] = value
  end
  hash
end

def Hash.new(pull : YAML::PullParser)
  pull.read_mapping_start
  while pull.kind != YAML::EventKind::MAPPING_END
    yield K.new(pull), V.new(pull)
  end
  pull.read_next
end

def Tuple.new(pull : YAML::PullParser)
  {% begin %}
    pull.read_sequence_start
    value = Tuple.new(
      {% for i in 0...T.size %}
        (self[{{i}}].new(pull)),
      {% end %}
    )
    pull.read_sequence_end
    value
 {% end %}
end

def NamedTuple.new(pull : YAML::PullParser)
  {% begin %}
    {% for key in T.keys %}
      %var{key.id} = nil
    {% end %}

    location = pull.location

    pull.read_mapping_start
    while pull.kind != YAML::EventKind::MAPPING_END
      key = pull.read_scalar
      case key
        {% for key, type in T %}
          when {{key.stringify}}
            %var{key.id} = {{type}}.new(pull)
        {% end %}
      else
        pull.skip
      end
    end
    pull.read_mapping_end

    {% for key in T.keys %}
      if %var{key.id}.nil?
        raise YAML::ParseException.new("Missing yaml attribute: {{key}}", *location)
      end
    {% end %}

    {
      {% for key in T.keys %}
        {{key}}: %var{key.id},
      {% end %}
    }
  {% end %}
end

def Enum.new(pull : YAML::PullParser)
  string = pull.read_scalar
  if value = string.to_i64?
    from_value(value)
  else
    parse(string)
  end
end

def Union.new(pull : YAML::PullParser)
  location = pull.location
  string = pull.read_raw
  {% for type in T %}
    begin
      return {{type}}.from_yaml(string)
    rescue YAML::ParseException
      # Ignore
    end
  {% end %}
  raise YAML::ParseException.new("Couldn't parse #{self} from #{string}", *location)
end

struct Time::Format
  def from_yaml(pull : YAML::PullParser)
    string = pull.read_scalar
    parse(string)
  end
end

module Time::EpochConverter
  def self.from_yaml(value : YAML::PullParser) : Time
    Time.epoch(value.read_scalar.to_i)
  end
end

module Time::EpochMillisConverter
  def self.from_yaml(value : YAML::PullParser) : Time
    Time.epoch_ms(value.read_scalar.to_i64)
  end
end
