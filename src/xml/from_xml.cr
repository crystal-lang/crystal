require "uuid"

def Object.from_xml(string_or_io)
  new XML.parse(string_or_io)
end

def Array.from_xml(string_or_io) : Nil
  parser = XML.parse(string_or_io)
  new(parser) do |node|
    yield node
  end
  nil
end

def Nil.new(node : XML::Node)
  node.read
  nil
end

def Bool.new(node : XML::Node)
  case node.content
  when "t", "true"
    true
  when "f", "false"
    false
  else
    raise XML::SerializableError.new(
      "failed to parse bool",
      Bool.name,
      nil,
      Int32::MIN
    )
  end
end

def Union.new(node : XML::Node)
  {% begin %}
    case content = node.content
    {% if T.includes? Nil %}
    when .blank?
      return nil
    {% end %}
    {% if T.includes? Bool %}
    when "true"
      return true
    when "false"
      return false
    {% end %}
    {%
      numeral_methods = {
        Int64   => "i64",
        UInt64  => "u64",
        Int32   => "i32",
        UInt32  => "u32",
        Int16   => "i16",
        UInt16  => "u16",
        Int8    => "i8",
        UInt8   => "u8",
        Float64 => "f64",
        Float32 => "f32",
      }
    %}
    {% type_order = [Int64, UInt64, Int32, UInt32, Int16, UInt16, Int8, UInt8, Float64, Float32] %}
    {% for type in type_order.select { |t| T.includes? t } %}
      when .to_{{numeral_methods[type].id}}?
        return content.not_nil!.to_{{numeral_methods[type].id}}
    {% end %}
    {% if T.includes? String %}
    else
      return node.content
    {% else %}
    else
      # no priority type
    {% end %}
    end
  {% end %}

  {% begin %}
    {% primitive_types = [Nil, Bool, String] + Number::Primitive.union_types %}
    {% non_primitives = T.reject { |t| primitive_types.includes? t } %}

    # If after traversing all the types we are left with just one
    # non-primitive type, we can parse it directly (no need to use `read_raw`)
    {% if non_primitives.size == 1 %}
      return {{non_primitives[0]}}.new(node)
    {% else %}
      string = node.content
      {% for type in non_primitives %}
        begin
          return {{type}}.from_xml(string)
        rescue XML::Error
          # Ignore
        end
      {% end %}
      raise XML::Error.new("Couldn't parse #{self} from #{string}", 0)
    {% end %}
  {% end %}
end

def Time.new(node : XML::Node)
  Time::Format::ISO_8601_DATE_TIME.parse(node.content)
end

struct Time::Format
  def from_xml(node : XML::Node) : Time
    string = node.content
    parse(string, Time::Location::UTC)
  end
end

def Nil.new(node : XML::Node)
  nil
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
  def {{type.id}}.new(node : XML::Node)
    begin
      value.to_{{method.id}}
    rescue ex : OverflowError | ArgumentError
      raise XML::ParseException.new("Can't read {{type.id}}", nil, ex)
    end
  end

  def {{type.id}}.from_xml_object_key?(key : String)
    key.to_{{method.id}}?
  end
{% end %}

def Nil.new(node : XML::Node)
  nil
end

def Int32.new(node : XML::Node)
  node.content.to_i
end

def Array.new(node : XML::Node)
  ary = new
  new(node) do |element|
    ary << element
  end
  ary
end

def Array.new(node : XML::Node)
  begin
    if node.document?
      root = node.root
      if root.nil?
        raise ::XML::SerializableError.new("Missing XML root document", self.class.to_s, nil, 0)
      else
        children = root.children
      end
    else
      children = node.children
    end
  rescue exc : ::XML::Error
    raise ::XML::SerializableError.new(exc.message, self.class.to_s, nil, exc.line_number)
  end

  children.each do |child|
    next unless child.element?
    yield T.new(child)
  end
end

def String.new(node : XML::Node)
  node.content
end

def Object.from_xml(string_or_io, root : String)
  parser = XML::Reader.new(string_or_io)
  parser.on_key!(root) do
    new parser
  end
end

def UUID.new(node : XML::Node)
  UUID.new(node.content)
end

def Hash.new(node : XML::Node)
  hash = new

  element = node.children
  if element.nil?
    raise XML::SerializableError.new(
      "Can't convert #{node.inspect} into Hash",
      self.class.to_s,
      nil,
      Int32::MIN
    )
  end

  element.each do |child|
    next unless child.element?

    parsed_key = child.name
    if parsed_key.nil?
      raise XML::SerializableError.new(
        "Can't convert #{parsed_key.inspect} into #{K}",
        self.class.to_s,
        nil,
        Int32::MIN
      )
    end
    hash[parsed_key] = V.new(child)
  end
  hash
end

module Time::EpochConverter
  def self.from_xml(node : XML::Node) : Time
    Time.unix(node.content.to_i)
  end
end

module Time::EpochMillisConverter
  def self.from_xml(node : XML::Node) : Time
    Time.unix_ms(node.content.to_i64)
  end
end

module String::RawConverter
  def self.from_xml(node : XML::Node) : String
    node.content.to_s
  end
end
