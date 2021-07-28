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
def Object.from_json(string_or_io)
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
def Object.from_json(string_or_io, root : String)
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

def Deque.from_json(string_or_io) : Nil
  parser = JSON::PullParser.new(string_or_io)
  new(parser) do |element|
    yield element
  end
end

def Nil.new(pull : JSON::PullParser)
  pull.read_null
end

def Bool.new(pull : JSON::PullParser)
  pull.read_bool
end

{% for type, method in {
                         "Int8"   => "i8",
                         "Int16"  => "i16",
                         "Int32"  => "i32",
                         "Int64"  => "i64",
                         "UInt8"  => "u8",
                         "UInt16" => "u16",
                         "UInt32" => "u32",
                         "UInt64" => "u64",
                       } %}
  def {{type.id}}.new(pull : JSON::PullParser)
    location = pull.location
    value = pull.read_int
    begin
      value.to_{{method.id}}
    rescue ex : OverflowError
      raise JSON::ParseException.new("Can't read {{type.id}}", *location, ex)
    end
  end

  def {{type.id}}.from_json_object_key?(key : String)
    key.to_{{method.id}}?
  end
{% end %}

def Float32.new(pull : JSON::PullParser)
  case pull.kind
  when .int?
    value = pull.int_value.to_f32
    pull.read_next
    value
  else
    pull.read_float.to_f32
  end
end

def Float32.from_json_object_key?(key : String) : Float32?
  key.to_f32?
end

def Float64.new(pull : JSON::PullParser)
  case pull.kind
  when .int?
    value = pull.int_value.to_f
    pull.read_next
    value
  else
    pull.read_float.to_f
  end
end

def Float64.from_json_object_key?(key : String) : Float64?
  key.to_f64?
end

def String.new(pull : JSON::PullParser)
  pull.read_string
end

def Path.new(pull : JSON::PullParser)
  new(pull.read_string)
end

def String.from_json_object_key?(key : String) : String
  key
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

def Deque.new(pull : JSON::PullParser)
  ary = new
  new(pull) do |element|
    ary << element
  end
  ary
end

def Deque.new(pull : JSON::PullParser)
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

# Reads a Hash from the given pull parser.
#
# Keys are read by invoking `from_json_object_key?` on this hash's
# key type (`K`), which must return a value of type `K` or `nil`.
# If `nil` is returned a `JSON::ParseException` is raised.
#
# Values are parsed using the regular `new(pull : JSON::PullParser)` method.
def Hash.new(pull : JSON::PullParser)
  hash = new
  pull.read_object do |key, key_location|
    parsed_key = K.from_json_object_key?(key)
    unless parsed_key
      raise JSON::ParseException.new("Can't convert #{key.inspect} into #{K}", *key_location)
    end
    hash[parsed_key] = V.new(pull)
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
      %found{key.id} = false
    {% end %}

    location = pull.location

    pull.read_object do |key|
      case key
        {% for key, type in T %}
          when {{key.stringify}}
            %var{key.id} = {{type}}.new(pull)
            %found{key.id} = true
        {% end %}
      else
        pull.skip
      end
    end

    {% for key, type in T %}
      if %var{key.id}.nil? && !%found{key.id} && !{{type.nilable?}}
        raise JSON::ParseException.new("Missing json attribute: {{key}}", *location)
      end
    {% end %}

    {
      {% for key, type in T %}
        {{key}}: (%var{key.id}).as({{type}}),
      {% end %}
    }
  {% end %}
end

# Reads a serialized enum member by name from *pull*.
#
# See `#to_json` for reference.
#
# Raises `JSON::ParseException` if the deserialization fails.
def Enum.new(pull : JSON::PullParser)
  {% if @type.annotation(Flags) %}
    value = {{ @type }}::None
    pull.read_array do
      value |= parse?(pull.read_string) || pull.raise "Unknown enum #{self} value: #{pull.string_value.inspect}"
    end
    value
  {% else %}
    parse?(pull.read_string) || pull.raise "Unknown enum #{self} value: #{pull.string_value.inspect}"
  {% end %}
end

# Converter for value-based serialization and deserialization of enum type `T`.
#
# The serialization format of `Enum#to_json` and `Enum.from_json` is based on
# the member name. This converter offers an alternative based on the member value.
#
# This converter can be used for its standalone serialization methods as a
# replacement of the default strategy of `Enum`. It also works as a serialization
# converter with `JSON::Field` and `YAML::Field`
#
# ```
# require "json"
# require "yaml"
#
# enum MyEnum
#   ONE = 1
#   TWO = 2
# end
#
# class Foo
#   include JSON::Serializable
#   include YAML::Serializable
#
#   @[JSON::Field(converter: Enum::ValueConverter(MyEnum))]
#   @[YAML::Field(converter: Enum::ValueConverter(MyEnum))]
#   property foo : MyEnum = MyEnum::ONE
#
#   def initialize(@foo)
#   end
# end
#
# foo = Foo.new(MyEnum::ONE)
# foo.to_json # => %({"foo":1})
# foo.to_yaml # => %(---\nfoo: 1\n)
# ```
#
# NOTE: Automatically assigned enum values are subject to change when the order
# of members by adding, removing or reordering them. This can affect the integrity
# of serialized data between two instances of a program based on different code
# versions. A way to avoid this is to explicitly assign fixed values to enum
# members.
module Enum::ValueConverter(T)
  def self.new(pull : JSON::PullParser) : T
    from_json(pull)
  end

  # Reads a serialized enum member by value from *pull*.
  #
  # See `.to_json` for reference.
  #
  # Raises `JSON::ParseException` if the deserialization fails.
  def self.from_json(pull : JSON::PullParser) : T
    T.from_value?(pull.read_int) || pull.raise "Unknown enum #{T} value: #{pull.int_value}"
  end
end

def Union.new(pull : JSON::PullParser)
  location = pull.location

  {% begin %}
    case pull.kind
    {% if T.includes? Nil %}
    when .null?
      return pull.read_null
    {% end %}
    {% if T.includes? Bool %}
    when .bool?
      return pull.read_bool
    {% end %}
    {% if T.includes? String %}
    when .string?
      return pull.read_string
    {% end %}
    when .int?
    {% type_order = [Int64, UInt64, Int32, UInt32, Int16, UInt16, Int8, UInt8, Float64, Float32] %}
    {% for type in type_order.select { |t| T.includes? t } %}
      value = pull.read?({{type}})
      return value unless value.nil?
    {% end %}
    when .float?
    {% type_order = [Float64, Float32] %}
    {% for type in type_order.select { |t| T.includes? t } %}
      value = pull.read?({{type}})
      return value unless value.nil?
    {% end %}
    else
      # no priority type
    end
  {% end %}

  {% begin %}
    {% primitive_types = [Nil, Bool, String] + Number::Primitive.union_types %}
    {% non_primitives = T.reject { |t| primitive_types.includes? t } %}

    # If after traversing all the types we are left with just one
    # non-primitive type, we can parse it directly (no need to use `read_raw`)
    {% if non_primitives.size == 1 %}
      return {{non_primitives[0]}}.new(pull)
    {% else %}
      string = pull.read_raw
      {% for type in non_primitives %}
        begin
          return {{type}}.from_json(string)
        rescue JSON::ParseException
          # Ignore
        end
      {% end %}
      raise JSON::ParseException.new("Couldn't parse #{self} from #{string}", *location)
    {% end %}
  {% end %}
end

# Reads a string from JSON parser as a time formatted according to [RFC 3339](https://tools.ietf.org/html/rfc3339)
# or other variations of [ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf).
#
# The JSON format itself does not specify a time data type, this method just
# assumes that a string holding a ISO 8601 time format can be interpreted as a
# time value.
#
# See `#to_json` for reference.
def Time.new(pull : JSON::PullParser)
  Time::Format::ISO_8601_DATE_TIME.parse(pull.read_string)
end

struct Time::Format
  def from_json(pull : JSON::PullParser) : Time
    string = pull.read_string
    parse(string, Time::Location::UTC)
  end
end

module JSON::ArrayConverter(Converter)
  def self.from_json(pull : JSON::PullParser)
    ary = Array(typeof(Converter.from_json(pull))).new
    pull.read_array do
      ary << Converter.from_json(pull)
    end
    ary
  end
end

module JSON::HashValueConverter(Converter)
  def self.from_json(pull : JSON::PullParser)
    hash = Hash(String, typeof(Converter.from_json(pull))).new
    pull.read_object do |key, key_location|
      parsed_key = String.from_json_object_key?(key)
      unless parsed_key
        raise JSON::ParseException.new("Can't convert #{key.inspect} into String", *key_location)
      end
      hash[parsed_key] = Converter.from_json(pull)
    end
    hash
  end
end

module Time::EpochConverter
  def self.from_json(value : JSON::PullParser) : Time
    Time.unix(value.read_int)
  end
end

module Time::EpochMillisConverter
  def self.from_json(value : JSON::PullParser) : Time
    Time.unix_ms(value.read_int)
  end
end

module String::RawConverter
  def self.from_json(value : JSON::PullParser) : String
    value.read_raw
  end
end
