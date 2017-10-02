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
  pull.read_null
end

def Bool.new(pull : YAML::PullParser)
  pull.read_bool
end

# TODO: Ideally, it may be beter to use `for type in Int::Primitive.union_types`
# but it is currently broken due to: https://github.com/crystal-lang/crystal/issues/4301
{% for bits in [8, 16, 32, 64] %}
  def Int{{bits}}.new(pull : YAML::PullParser)
     pull.read_int.to_i{{bits}}
  end

  def UInt{{bits}}.new(pull : YAML::PullParser)
   pull.read_int.to_u{{bits}}
  end
{% end %}

{% for bits in [32, 64] %}
  def Float{{bits}}.new(pull : YAML::PullParser)
    pull.read_float.to_f{{bits}}
  end
{% end %}

# TODO: Implement a Time parser that supports all the YAML formats
def Time.new(pull : YAML::PullParser)
  pull.read_timestamp
end

def String.new(pull : YAML::PullParser)
  pull.read_string
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
