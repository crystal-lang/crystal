# Deserializes the given JSON in *string_or_io* into
# an instance of `self`. This simply creates a `parser = JSON::PullParser`
# and invokes `new(parser)`: classes that want to provide JSON
# deserialization must provide an `def initialize(parser : JSON::PullParser)`
# method.
#
# ```
# Int32.from_json("1")                # => 1
# Array(Int32).from_json("[1, 2, 3]") # => [1, 2, 3]
# ```
def Object.from_json(string_or_io) : self
  parser = JSON::PullParser.new(string_or_io)
  new parser
end

# Deserializes the given JSON in *string_or_io* into
# an instance of `self`, assuming the JSON consists
# of an JSON object with key *root*, and whose value is
# the value to deserialize.
#
# ```
# Int32.from_json(%({"main": 1}), root: "main") # => 1
# ```
def Object.from_json(string_or_io, root : String) : self
  parser = JSON::PullParser.new(string_or_io)
  parser.on_key!(root) do
    new parser
  end
end

# Parses a `String` or `IO` denoting a JSON array, yielding
# each of its elements to the given block. This is useful
# for decoding an array and processing its elements without
# creating an Array in memory, which might be expensive.
#
# ```
# require "json"
#
# Array(Int32).from_json("[1, 2, 3]") do |element|
#   puts element
# end
# ```
#
# Output:
#
# ```text
# 1
# 2
# 3
# ```
#
# To parse and get an `Array`, use the block-less overload.
def Array.from_json(string_or_io) : Nil
  parser = JSON::PullParser.new(string_or_io)
  new(parser) do |element|
    yield element
  end
  nil
end

def Nil.new(pull : JSON::PullParser)
  pull.read_null
end

def Bool.new(pull : JSON::PullParser)
  pull.read_bool
end

{% for type in %w(Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64) %}
  def {{type.id}}.new(pull : JSON::PullParser)
    {{type.id}}.new(pull.read_int)
  end
{% end %}

def Float32.new(pull : JSON::PullParser)
  case pull.kind
  when :int
    value = pull.int_value.to_f32
    pull.read_next
    value
  else
    pull.read_float.to_f32
  end
end

def Float64.new(pull : JSON::PullParser)
  case pull.kind
  when :int
    value = pull.int_value.to_f
    pull.read_next
    value
  else
    pull.read_float.to_f
  end
end

def String.new(pull : JSON::PullParser)
  pull.read_string
end

def Array.new(pull : JSON::PullParser)
  ary = new
  new(pull) do |element|
    ary << element
  end
  ary
end

def Array.new(pull : JSON::PullParser)
  pull.read_array do
    yield T.new(pull)
  end
end

def Set.new(pull : JSON::PullParser)
  set = new
  pull.read_array do
    set << T.new(pull)
  end
  set
end

def Hash.new(pull : JSON::PullParser)
  hash = new
  pull.read_object do |key|
    if pull.kind == :null
      pull.read_next
    else
      hash[key] = V.new(pull)
    end
  end
  hash
end

def Tuple.new(pull : JSON::PullParser)
  {% begin %}
    pull.read_begin_array
    value = Tuple.new(
      {% for i in 0...T.size %}
        (self[{{i}}].new(pull)),
      {% end %}
    )
    pull.read_end_array
    value
 {% end %}
end

def NamedTuple.new(pull : JSON::PullParser)
  {% begin %}
    {% for key in T.keys %}
      %var{key.id} = nil
    {% end %}

    location = pull.location

    pull.read_object do |key|
      case key
        {% for key, type in T %}
          when {{key.stringify}}
            %var{key.id} = {{type}}.new(pull)
        {% end %}
      else
        pull.skip
      end
    end

    {% for key in T.keys %}
      if %var{key.id}.nil?
        raise JSON::ParseException.new("Missing json attribute: {{key}}", *location)
      end
    {% end %}

    {
      {% for key in T.keys %}
        {{key}}: %var{key.id},
      {% end %}
    }
  {% end %}
end

def Enum.new(pull : JSON::PullParser)
  case pull.kind
  when :int
    from_value(pull.read_int)
  when :string
    parse(pull.read_string)
  else
    raise "Expecting int or string in JSON for #{self.class}, not #{pull.kind}"
  end
end

def Union.new(pull : JSON::PullParser)
  location = pull.location

  # Optimization: use fast path for primitive types
  {% begin %}
    # Here we store types that are not primitive types
    {% non_primitives = [] of Nil %}

    {% for type, index in T %}
      {% if type == Nil %}
        return pull.read_null if pull.kind == :null
      {% elsif type == Bool ||
                 type == Int8 || type == Int16 || type == Int32 || type == Int64 ||
                 type == UInt8 || type == UInt16 || type == UInt32 || type == UInt64 ||
                 type == Float32 || type == Float64 ||
                 type == String %}
        value = pull.read?({{type}})
        return value unless value.nil?
      {% else %}
        {% non_primitives << type %}
      {% end %}
    {% end %}

    # If after traversing all the types we are left with just one
    # non-primitive type, we can parse it directly (no need to use `read_raw`)
    {% if non_primitives.size == 1 %}
      return {{non_primitives[0]}}.new(pull)
    {% end %}
  {% end %}

  string = pull.read_raw
  {% for type in T %}
    begin
      return {{type}}.from_json(string)
    rescue JSON::ParseException
      # Ignore
    end
  {% end %}
  raise JSON::ParseException.new("Couldn't parse #{self} from #{string}", *location)
end

def Time.new(pull : JSON::PullParser)
  Time::Format::ISO_8601_DATE_TIME.parse(pull.read_string)
end

struct Time::Format
  def from_json(pull : JSON::PullParser)
    string = pull.read_string
    parse(string)
  end
end

module Time::EpochConverter
  def self.from_json(value : JSON::PullParser) : Time
    Time.epoch(value.read_int)
  end
end

module Time::EpochMillisConverter
  def self.from_json(value : JSON::PullParser) : Time
    Time.epoch_ms(value.read_int)
  end
end

module String::RawConverter
  def self.from_json(value : JSON::PullParser)
    value.read_raw
  end
end
