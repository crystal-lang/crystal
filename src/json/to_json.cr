class Object
  def to_json
    String.build do |str|
      to_json str
    end
  end

  def to_pretty_json
    String.build do |str|
      to_pretty_json str
    end
  end

  def to_pretty_json(io : IO)
    to_json JSON::PrettyWriter.new(io)
  end
end

# Handly struct to write JSON objects
struct JSON::ObjectBuilder(T)
  def initialize(@io : T, @indent = 0)
    @count = 0
  end

  # Adds a field to this JSON object
  def field(name, value)
    field(name) { value.to_json(@io) }
  end

  # Adds a field to this JSON object by specifying
  # it's name, then executes the block, which must append the value.
  def field(name)
    if @count > 0
      @io << ","
      @io << '\n' if @indent > 0
    end
    @indent.times { @io << "  " }
    @io << "\""
    name.to_s(@io)
    @io << "\":"
    @io << " " if @indent > 0
    yield
    @count += 1
  end
end

# Handly struct to write JSON arrays
struct JSON::ArrayBuilder(T)
  def initialize(@io : T, @indent = 0)
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
      @io << '\n' if @indent > 0
    end
    @indent.times { @io << "  " }
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
# result #=> %({"address":"Crystal Road 1234","location":[12.3,34.5]})
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

  def initialize(@io)
    @indent = 0
  end

  delegate read, @io
  delegate write, @io

  def json_object
    self << "{\n"
    @indent += 1
    yield JSON::ObjectBuilder.new(self, @indent)
    @indent -= 1
    self << '\n'
    @indent.times { @io << "  " }
    self << "}"
  end

  def json_array
    self << "[\n"
    @indent += 1
    yield JSON::ArrayBuilder.new(self, @indent)
    @indent -= 1
    self << '\n'
    @indent.times { @io << "  " }
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
    to_s io
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
      when .control?
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
      {% for i in 0 ... @length %}
        array << self[{{i}}]
      {% end %}
    end
  end
end

struct TimeFormat
  def to_json(value : Time, io : IO)
    format(value).to_json(io)
  end
end
