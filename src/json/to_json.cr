class Object
  def to_json : String
    String.build do |str|
      to_json str
    end
  end

  def to_json(io : IO) : Nil
    JSON.build(io) do |json|
      to_json(json)
    end
  end

  def to_pretty_json(indent : String = "  ") : String
    String.build do |str|
      to_pretty_json str, indent: indent
    end
  end

  def to_pretty_json(io : IO, indent : String = "  ") : Nil
    JSON.build(io, indent: indent) do |json|
      to_json(json)
    end
  end
end

struct Nil
  def to_json(json : JSON::Builder)
    json.null
  end

  def to_json_object_key : String
    ""
  end
end

struct Bool
  def to_json(json : JSON::Builder)
    json.bool(self)
  end
end

struct Int
  def to_json(json : JSON::Builder)
    json.number(self)
  end

  def to_json_object_key : String
    to_s
  end
end

struct Float
  def to_json(json : JSON::Builder)
    json.number(self)
  end

  def to_json_object_key : String
    to_s
  end
end

class String
  def to_json(json : JSON::Builder)
    json.string(self)
  end

  def to_json_object_key : String
    self
  end
end

struct Path
  def to_json(json : JSON::Builder)
    @name.to_json(json)
  end

  def to_json_object_key
    @name
  end
end

struct Symbol
  def to_json(json : JSON::Builder)
    json.string(to_s)
  end

  def to_json_object_key : String
    to_s
  end
end

class Array
  def to_json(json : JSON::Builder)
    json.array do
      each &.to_json(json)
    end
  end
end

class Deque
  def to_json(json : JSON::Builder)
    json.array do
      each &.to_json(json)
    end
  end
end

struct Set
  def to_json(json : JSON::Builder)
    json.array do
      each &.to_json(json)
    end
  end
end

class Hash
  # Serializes this Hash into JSON.
  #
  # Keys are serialized by invoking `to_json_object_key` on them.
  # Values are serialized with the usual `to_json(json : JSON::Builder)`
  # method.
  def to_json(json : JSON::Builder)
    json.object do
      each do |key, value|
        json.field key.to_json_object_key do
          value.to_json(json)
        end
      end
    end
  end
end

struct Tuple
  def to_json(json : JSON::Builder)
    json.array do
      {% for i in 0...T.size %}
        self[{{i}}].to_json(json)
      {% end %}
    end
  end
end

struct NamedTuple
  def to_json(json : JSON::Builder)
    json.object do
      {% for key in T.keys %}
        json.field {{key.stringify}} do
          self[{{key.symbolize}}].to_json(json)
        end
      {% end %}
    end
  end
end

struct Time::Format
  def to_json(value : Time, json : JSON::Builder)
    format(value).to_json(json)
  end
end

struct Enum
  # Serializes this enum member by name.
  #
  # For non-flags enums, the serialization is a JSON string. The value is the
  # member name (see `#to_s`) transformed with `String#underscore`.
  #
  # ```
  # enum Stages
  #   INITIAL
  #   SECOND_STAGE
  # end
  #
  # Stages::INITIAL.to_json      # => %("initial")
  # Stages::SECOND_STAGE.to_json # => %("second_stage")
  # ```
  #
  # For flags enums, the serialization is a JSON array including every flagged
  # member individually serialized in the same way as a member of a non-flags enum.
  # `None` is serialized as an empty array, `All` as an array containing
  # all members.
  #
  # ```
  # @[Flags]
  # enum Sides
  #   LEFT
  #   RIGHT
  # end
  #
  # Sides::LEFT.to_json                  # => %(["left"])
  # (Sides::LEFT | Sides::RIGHT).to_json # => %(["left","right"])
  # Sides::All.to_json                   # => %(["left","right"])
  # Sides::None.to_json                  # => %([])
  # ```
  #
  # `ValueConverter.to_json` offers a different serialization strategy based on the
  # member value.
  def to_json(json : JSON::Builder)
    {% if @type.annotation(Flags) %}
      json.array do
        each do |member, _value|
          json.string(member.to_s.underscore)
        end
      end
    {% else %}
      json.string(to_s.underscore)
    {% end %}
  end
end

module Enum::ValueConverter(T)
  def self.to_json(value : T)
    String.build do |io|
      to_json(value, io)
    end
  end

  def self.to_json(value : T, io : IO)
    JSON.build(io) do |json|
      to_json(value, json)
    end
  end

  # Serializes enum member *member* by value.
  #
  # For both flags enums and non-flags enums, the value of the enum member is
  # used for serialization.
  #
  # ```
  # enum Stages
  #   INITIAL
  #   SECOND_STAGE
  # end
  #
  # Enum::ValueConverter.to_json(Stages::INITIAL)      # => %(0)
  # Enum::ValueConverter.to_json(Stages::SECOND_STAGE) # => %(1)
  #
  # @[Flags]
  # enum Sides
  #   LEFT
  #   RIGHT
  # end
  #
  # Enum::ValueConverter.to_json(Sides::LEFT)                # => %(1)
  # Enum::ValueConverter.to_json(Sides::LEFT | Sides::RIGHT) # => %(3)
  # Enum::ValueConverter.to_json(Sides::All)                 # => %(3)
  # Enum::ValueConverter.to_json(Sides::None)                # => %(0)
  # ```
  #
  # `Enum#to_json` offers a different serialization strategy based on the member
  # name.
  def self.to_json(member : T, json : JSON::Builder)
    json.scalar(member.value)
  end
end

struct Time
  # Emits a string formatted according to [RFC 3339](https://tools.ietf.org/html/rfc3339)
  # ([ISO 8601](http://xml.coverpages.org/ISO-FDIS-8601.pdf) profile).
  #
  # The JSON format itself does not specify a time data type, this method just
  # assumes that a string holding a RFC 3339 time format will be interpreted as
  # a time value.
  #
  # See `#from_json` for reference.
  def to_json(json : JSON::Builder)
    json.string(Time::Format::RFC_3339.format(self, fraction_digits: 0))
  end
end

# Converter to be used with `JSON::Serializable`
# to serialize the `Array(T)` elements with the custom converter.
#
# ```
# require "json"
#
# class TimestampArray
#   include JSON::Serializable
#
#   @[JSON::Field(converter: JSON::ArrayConverter(Time::EpochConverter))]
#   property dates : Array(Time)
# end
#
# timestamp = TimestampArray.from_json(%({"dates":[1459859781,1567628762]}))
# timestamp.dates   # => [2016-04-05 12:36:21 UTC, 2019-09-04 20:26:02 UTC]
# timestamp.to_json # => %({"dates":[1459859781,1567628762]})
# ```
module JSON::ArrayConverter(Converter)
  def self.to_json(values : Array, builder : JSON::Builder)
    builder.array do
      values.each do |value|
        Converter.to_json(value, builder)
      end
    end
  end
end

# Converter to be used with `JSON::Serializable`
# to serialize the `Hash(K, V)` values elements with the custom converter.
#
# ```
# require "json"
#
# class TimestampHash
#   include JSON::Serializable
#
#   @[JSON::Field(converter: JSON::HashValueConverter(Time::EpochConverter))]
#   property birthdays : Hash(String, Time)
# end
#
# timestamp = TimestampHash.from_json(%({"birthdays":{"foo":1459859781,"bar":1567628762}}))
# timestamp.birthdays # => {"foo" => 2016-04-05 12:36:21 UTC, "bar" => 2019-09-04 20:26:02 UTC)}
# timestamp.to_json   # => {"birthdays":{"foo":1459859781,"bar":1567628762}}
# ```
module JSON::HashValueConverter(Converter)
  def self.to_json(values : Hash, builder : JSON::Builder)
    builder.object do
      values.each do |key, value|
        builder.field key.to_json_object_key do
          Converter.to_json(value, builder)
        end
      end
    end
  end
end

# Converter to be used with `JSON::Serializable` and `YAML::Serializable`
# to serialize a `Time` instance as the number of seconds
# since the unix epoch. See `Time#to_unix`.
#
# ```
# require "json"
#
# class Person
#   include JSON::Serializable
#
#   @[JSON::Field(converter: Time::EpochConverter)]
#   property birth_date : Time
# end
#
# person = Person.from_json(%({"birth_date": 1459859781}))
# person.birth_date # => 2016-04-05 12:36:21 UTC
# person.to_json    # => %({"birth_date":1459859781})
# ```
module Time::EpochConverter
  def self.to_json(value : Time, json : JSON::Builder)
    json.number(value.to_unix)
  end
end

# Converter to be used with `JSON::Serializable` and `YAML::Serializable`
# to serialize a `Time` instance as the number of milliseconds
# since the unix epoch. See `Time#to_unix_ms`.
#
# ```
# require "json"
#
# class Timestamp
#   include JSON::Serializable
#
#   @[JSON::Field(converter: Time::EpochMillisConverter)]
#   property value : Time
# end
#
# timestamp = Timestamp.from_json(%({"value": 1459860483856}))
# timestamp.value   # => 2016-04-05 12:48:03.856 UTC
# timestamp.to_json # => %({"value":1459860483856})
# ```
module Time::EpochMillisConverter
  def self.to_json(value : Time, json : JSON::Builder)
    json.number(value.to_unix_ms)
  end
end

# Converter to be used with `JSON::Serializable` to read the raw
# value of a JSON object property as a `String`.
#
# It can be useful to read ints and floats without losing precision,
# or to read an object and deserialize it later based on some
# condition.
#
# ```
# require "json"
#
# class Raw
#   include JSON::Serializable
#
#   @[JSON::Field(converter: String::RawConverter)]
#   property value : String
# end
#
# raw = Raw.from_json(%({"value": 123456789876543212345678987654321}))
# raw.value   # => "123456789876543212345678987654321"
# raw.to_json # => %({"value":123456789876543212345678987654321})
# ```
module String::RawConverter
  def self.to_json(value : String, json : JSON::Builder)
    json.raw(value)
  end
end
