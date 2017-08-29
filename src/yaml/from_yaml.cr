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

# TODO: Ideally, it may be beter to use `for type in Int::Primitive.union_types`
# but it is currently broken due to: https://github.com/crystal-lang/crystal/issues/4301
{% for bits in [8, 16, 32, 64] %}
  {% for type in %w(Int UInt) %}
    def {{type.id}}{{bits}}.new(pull : YAML::PullParser)
      location = pull.location
      value = pull.read_plain_scalar

      number = {% if type == "UInt" %}
        value.to_u{{bits}}?(underscore: false, prefix: true)
      {% else %}
        value.to_i{{bits}}?(underscore: false, prefix: true)
      {% end %}
      return number if number

      raise YAML::ParseException.new("Invalid {{type.id}}{{bits}} number", *location)
    end
  {% end %}
{% end %}

{% for bits in [32, 64] %}
  def Float{{bits}}.new(pull : YAML::PullParser)
    location = pull.location
    value = pull.read_plain_scalar
    if float = value.to_f{{bits}}?
      float
    elsif YAML::INFINITY_VALUES.includes? value.lchop('+')
      INFINITY
    elsif value[0]? == '-' && YAML::INFINITY_VALUES.includes?(value.lchop('-'))
      -INFINITY
    elsif YAML::NAN_VALUES.includes? value
      NAN
    else
      raise YAML::ParseException.new("Invalid Float{{bits}} number", *location)
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
  if pull.data.scalar.style == LibYAML::ScalarStyle::PLAIN
    pull.read_plain_scalar.tap do |value|
      if YAML.reserved_value?(value)
        raise YAML::ParseException.new(%(Expected string, not "#{value}"), *location)
      end
    end
  else
    pull.read_scalar
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
