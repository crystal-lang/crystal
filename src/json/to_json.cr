class Object
  def to_json
    String.build do |str|
      to_json str
    end
  end
end

struct Json::ObjectBuilder(T)
  def initialize(@io : T)
    @count = 0
  end

  def field(name, value)
    field(name) { value.to_json(@io) }
  end

  def field(name)
    @io << "," if @count > 0
    @io << "\""
    name.to_s(@io)
    @io << "\":"
    yield
    @count += 1
  end
end

struct Json::ArrayBuilder(T)
  def initialize(@io : T)
    @count = 0
  end

  def <<(value)
    @io << "," if @count > 0
    value.to_json(@io)
    @count += 1
  end
end

module Json::Builder
  def json_object
    self << "{"
    yield Json::ObjectBuilder.new(self)
    self << "}"
  end

  def json_array
    self << "["
    yield Json::ArrayBuilder.new(self)
    self << "]"
  end
end

module IO
  include Json::Builder
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
      when 8.chr # TODO use '\b'
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
    io.json_array do |array|
      each do |element|
        array << element
      end
    end
  end
end

class Hash
  def to_json(io)
    io.json_object do |object|
      each do |key, value|
        object.field key, value
      end
    end
  end
end
