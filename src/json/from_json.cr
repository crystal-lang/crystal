def Object.from_json(string_or_io) : self
  parser = JSON::PullParser.new(string_or_io)
  new parser
end

# Parses a String or IO denoting a JSON array, yielding
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
# To parse and get an Array, use the block-less overload.
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
  {% if true %}
    pull.read_begin_array
    value = Tuple.new(
      {% for i in 0...@type.size %}
        (self[{{i}}].new(pull)),
      {% end %}
    )
    pull.read_end_array
    value
 {% end %}
end

def Enum.new(pull : JSON::PullParser)
  case pull.kind
  when :int
    from_value(pull.read_int)
  when :string
    parse(pull.read_string)
  else
    raise "expecting int or string in JSON for #{self.class}, not #{pull.kind}"
  end
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
