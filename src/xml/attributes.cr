require "./node"

class XML::Attributes
  include Enumerable(Node)

  # :nodoc:
  def initialize(@node : Node)
  end

  def empty? : Bool
    return true unless @node.element?

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
    if prop = find_prop(name)
      # manually unlink the prop's children if we have live references, so
      # xmlSetProp won't free them immediately
      @node.document.unlink_cached_children(prop)
    end

    LibXML.xmlSetProp(@node, name, value.to_s)
    value
  end

  def delete(name : String) : String?
    prop = find_prop(name)
    return unless prop

    value = XML.node_content_to_string(prop)

    if node = @node.document.cached?(prop)
      # can't call xmlUnsetProp: it would free the node
      node.unlink
      value
    else
      # manually unlink the prop's children if we have live references, so
      # xmlUnsetProp won't free them immediately
      @node.document.unlink_cached_children(prop)
      value if LibXML.xmlUnsetProp(@node, name) == 0
    end
  end

  private def find_prop(name)
    prop = @node.to_unsafe.value.properties.as(LibXML::Node*)
    while prop
      if String.new(prop.value.name) == name
        return prop
      end
      prop = prop.value.next
    end
  end

  def each(&) : Nil
    return unless @node.element?

    props = self.props
    until props.null?
      yield Node.new(props.as(LibXML::Node*), @node.document)
      props = props.value.next.as(LibXML::Attr*)
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

  def pretty_print(pp : PrettyPrint) : Nil
    pp.list("[", self, "]")
  end

  protected def props : LibXML::Attr*
    @node.to_unsafe.value.properties
  end
end
