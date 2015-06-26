struct XML::Attributes
  include Enumerable(Node)

  def initialize(@node)
  end

  def empty?
    return true unless @node.element?

    props = self.props()
    props.nil?
  end

  def length
    count
  end

  def [](index : Int)
    length = self.length

    index += length if index < 0

    unless 0 <= index < length
      raise IndexError.new
    end

    each_with_index do |node, i|
      return node if i == index
    end

    raise IndexError.new
  end

  def [](name : String)
    self[name]? || raise KeyError.new("Missing attribute: #{name}")
  end

  def []?(name : String)
    find { |node| node.name == name }
  end

  def each
    return unless @node.element?

    props = self.props()
    until props.nil?
      yield Node.new(props)
      props = props.value.next
    end
  end

  def to_s(io)
    io << "["
    join ", ", io, &.inspect(io)
    io << "]"
  end

  def inspect(io)
    to_s(io)
  end

  protected def props
    @node.to_unsafe.value.properties
  end
end
