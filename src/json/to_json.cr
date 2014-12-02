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

struct JSON::ObjectBuilder(T)
  def initialize(@io : T, @indent = 0)
    @count = 0
  end

  def field(name, value)
    field(name) { value.to_json(@io) }
  end

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

struct JSON::ArrayBuilder(T)
  def initialize(@io : T, @indent = 0)
    @count = 0
  end

  def <<(value)
    if @count > 0
      @io << ","
      @io << '\n' if @indent > 0
    end
    @indent.times { @io << "  " }
    value.to_json(@io)
    @count += 1
  end
end

module JSON::Builder
  def json_object
    self << "{"
    yield JSON::ObjectBuilder.new(self)
    self << "}"
  end

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

struct TimeFormat
  def to_json(value : Time, io : IO)
    format(value).to_json(io)
  end
end
