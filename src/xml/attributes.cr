require "./node"

class XML::Attributes
  include Enumerable(Node)

  def initialize(@node : Node)
  end

  def empty? : Bool
    return true unless @node.element?

    props = self.props
    props.null?
  end

  def [](index : Int) : XML::Node
    # TODO: Optimize to avoid double iteration
    size = self.size

    index += size if index < 0

    unless 0 <= index < size
      raise IndexError.new
    end

    each_with_index do |node, i|
      return node if i == index
    end

    raise IndexError.new
  end

  def [](name : String) : XML::Node
    self[name]? || raise KeyError.new("Missing attribute: #{name}")
  end

  def []?(name : String) : XML::Node?
    find { |node| node.name == name }
  end

  def []=(name : String, value)
    LibXML.xmlSetProp(@node, name, value.to_s)
    value
  end

  def delete(name : String) : String?
    value = self[name]?.try &.content
    res = LibXML.xmlUnsetProp(@node, name)
    value if res == 0
  end

  def each(&) : Nil
    return unless @node.element?

    props = self.props
    until props.null?
      yield Node.new(props)
      props = props.value.next
    end
  end

  def to_s(io : IO) : Nil
    io << '['
    join io, ", ", &.inspect(io)
    io << ']'
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  protected def props
    @node.to_unsafe.value.properties
  end
end
