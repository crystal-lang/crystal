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
    @io << ", " if @count > 0
    @io << "\""
    @io << name
    @io << "\": "
    yield
    @count += 1
  end
end

struct Json::ArrayBuilder(T)
  def initialize(@io : T)
    @count = 0
  end

  def <<(value)
    @io << ", " if @count > 0
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

class StringBuilder
  include Json::Builder
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
    io << to_s
  end
end

struct Int
  def to_json(io)
    io << to_s
  end
end

struct Float
  def to_json(io)
    io << to_s
  end
end

class String
  def to_json(io)
    io << "\""
    io << dump
    io << "\""
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
