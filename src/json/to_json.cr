class Object
  def to_json
    String.build do |str|
      to_json str
    end
  end

  def to_pretty_json(indent : String = "  ")
    String.build do |str|
      to_pretty_json str, indent: indent
    end
  end

  def to_pretty_json(io : IO, indent : String = "  ")
    to_json JSON::PrettyWriter.new(io, indent: indent)
  end
end

# Handly struct to write JSON objects
struct JSON::ObjectBuilder(T)
  def initialize(@io : T, @indent : String = "  ", @indent_level : Int32 = 0)
    @count = 0
  end

  # Adds a field to this JSON object
  def field(name, value)
    field(name) { value.to_json(@io) }
  end

  # Adds a field to this JSON object, with raw JSON object as string
  def raw_field(name, value)
    field(name) { value.to_s(@io) }
  end

  # Adds a field to this JSON object by specifying
  # it's name, then executes the block, which must append the value.
  def field(name)
    if @count > 0
      @io << ","
      @io << '\n' if @indent_level > 0
    end
    @indent_level.times { @io << @indent }
    name.to_s.to_json(@io)
    @io << ":"
    @io << " " if @indent_level > 0
    yield
    @count += 1
  end
end

# Handly struct to write JSON arrays
struct JSON::ArrayBuilder(T)
  def initialize(@io : T, @indent : String = "  ", @indent_level : Int32 = 0)
    @count = 0
  end

  # Appends a JSON value into this array
  def <<(value)
    push value
  end

  # Same as `#<<`
  def push(value)
    push { value.to_json(@io) }
  end

  # Executes the block, expecting it to append a value
  # in this array
  def push
    if @count > 0
      @io << ","
      @io << '\n' if @indent_level > 0
    end
    @indent_level.times { @io << @indent }
    yield
    @count += 1
  end
end

# The `JSON::Builder` module adds two methods, `json_object` and `json_array`
# to all `IO`s so generating JSON by streaming to an IO is easy and convenient.
#
# ### Example
#
# ```
# require "json"
#
# result = String.build do |io|
#   io.json_object do |object|
#     object.field "address", "Crystal Road 1234"
#     object.field "location" do
#       io.json_array do |array|
#         array << 12.3
#         array << 34.5
#       end
#     end
#   end
# end
# result # => %({"address":"Crystal Road 1234","location":[12.3,34.5]})
# ```
module JSON::Builder
  # Writes a JSON object to the given IO. Yields a `JSON::ObjectBuilder`.
  def json_object
    self << "{"
    yield JSON::ObjectBuilder.new(self)
    self << "}"
  end

  # Writes a JSON array to the given IO. Yields a `JSON::ArrayBuilder`.
  def json_array
    self << "["
    yield JSON::ArrayBuilder.new(self)
    self << "]"
  end
end

module IO
  include JSON::Builder
end

class JSON::PrettyWriter
  include IO

  def initialize(@io : IO, @indent : String)
    @indent_level = 0
  end

  delegate read, to: @io
  delegate write, to: @io

  def json_object
    self << "{\n"
    @indent_level += 1
    yield JSON::ObjectBuilder.new(self, @indent, @indent_level)
    @indent_level -= 1
    self << '\n'
    @indent_level.times { @io << @indent }
    self << "}"
  end

  def json_array
    self << "[\n"
    @indent_level += 1
    yield JSON::ArrayBuilder.new(self, @indent, @indent_level)
    @indent_level -= 1
    self << '\n'
    @indent_level.times { @io << @indent }
    self << ']'
  end
end

struct Nil
  def to_json(io)
    io << "null"
  end
end

struct Bool
  def to_json(io)
    to_s io
  end
end

struct Int
  def to_json(io)
    to_s io
  end
end

struct Float
  def to_json(io)
    case self
    when .nan?
      raise JSON::Error.new("NaN not allowed in JSON")
    when .infinite?
      raise JSON::Error.new("Infinity not allowed in JSON")
    else
      to_s io
    end
  end
end

class String
  def to_json(io)
    io << '"'
    each_char do |char|
      case char
      when '\\'
        io << "\\\\"
      when '"'
        io << "\\\""
      when '\b'
        io << "\\b"
      when '\f'
        io << "\\f"
      when '\n'
        io << "\\n"
      when '\r'
        io << "\\r"
      when '\t'
        io << "\\t"
      when .ascii_control?
        io << "\\u"
        ord = char.ord
        io << '0' if ord < 0x1000
        io << '0' if ord < 0x100
        io << '0' if ord < 0x10
        ord.to_s(16, io)
      else
        io << char
      end
    end
    io << '"'
  end
end

struct Symbol
  def to_json(io)
    to_s.to_json(io)
  end
end

class Array
  def to_json(io)
    if empty?
      io << "[]"
      return
    end

    io.json_array do |array|
      each do |element|
        array << element
      end
    end
  end
end

struct Set
  def to_json(io)
    if empty?
      io << "[]"
      return
    end

    io.json_array do |array|
      each do |element|
        array << element
      end
    end
  end
end

class Hash
  def to_json(io)
    if empty?
      io << "{}"
      return
    end

    io.json_object do |object|
      each do |key, value|
        object.field key, value
      end
    end
  end
end

struct Tuple
  def to_json(io)
    io.json_array do |array|
      {% for i in 0...T.size %}
        array << self[{{i}}]
      {% end %}
    end
  end
end

struct NamedTuple
  def to_json(io : IO)
    io.json_object do |obj|
      {% for key in T.keys %}
        obj.field({{key.stringify}}, self[{{key.symbolize}}])
      {% end %}
    end
  end
end

struct Time::Format
  def to_json(value : Time, io : IO)
    format(value).to_json(io)
  end
end

struct Enum
  def to_json(io)
    io << value
  end
end

struct Time
  def to_json(io)
    io << '"'
    Time::Format::ISO_8601_DATE_TIME.format(self, io)
    io << '"'
  end
end

# Converter to be used with `JSON.mapping` and `YAML.mapping`
# to serialize a `Time` instance as the number of seconds
# since the unix epoch. See `Time.epoch`.
#
# ```
# require "json"
#
# class Person
#   JSON.mapping({
#     birth_date: {type: Time, converter: Time::EpochConverter},
#   })
# end
#
# person = Person.from_json(%({"birth_date": 1459859781}))
# person.birth_date # => 2016-04-05 12:36:21 UTC
# person.to_json    # => %({"birth_date":1459859781})
# ```
module Time::EpochConverter
  def self.to_json(value : Time, io : IO)
    io << value.epoch
  end
end

# Converter to be used with `JSON.mapping` and `YAML.mapping`
# to serialize a `Time` instance as the number of milliseconds
# since the unix epoch. See `Time.epoch_ms`.
#
# ```
# require "json"
#
# class Person
#   JSON.mapping({
#     birth_date: {type: Time, converter: Time::EpochMillisConverter},
#   })
# end
#
# person = Person.from_json(%({"birth_date": 1459860483856}))
# person.birth_date # => 2016-04-05 12:48:03 UTC
# person.to_json    # => %({"birth_date":1459860483856})
# ```
module Time::EpochMillisConverter
  def self.to_json(value : Time, io : IO)
    io << value.epoch_ms
  end
end

# Converter to be used with `JSON.mapping` to read the raw
# value of a JSON object property as a String.
#
# It can be useful to read ints and floats without losing precision,
# or to read an object and deserialize it later based on some
# condition.
#
# ```
# require "json"
#
# class Raw
#   JSON.mapping({
#     value: {type: String, converter: String::RawConverter},
#   })
# end
#
# raw = Raw.from_json(%({"value": 123456789876543212345678987654321}))
# raw.value   # => "123456789876543212345678987654321"
# raw.to_json # => %({"value":123456789876543212345678987654321})
# ```
module String::RawConverter
  def self.to_json(value : String, io : IO)
    io << value
  end
end
