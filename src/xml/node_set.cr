class XML::NodeSet
  include Enumerable(Node)

  # :nodoc:
  def initialize(@doc : Node, @xpath_object : LibXML::XPathObject*)
    @set = @xpath_object.value.nodesetval
  end

  # :nodoc:
  def initialize(@doc : Node, @set : LibXML::NodeSet*)
    @xpath_object = Pointer(LibXML::XPathObject).null
  end

  # :nodoc:
  def initialize(@doc : Node)
    @xpath_object = Pointer(LibXML::XPathObject).null
    @set = LibXML.xmlXPathNodeSetCreate(nil)
  end

  # :nodoc:
  def finalize
    if @xpath_object.null?
      LibXML.xmlXPathFreeNodeSet(@set)
    else
      LibXML.xmlXPathFreeObject(@xpath_object)
    end
  end

  def [](index : Int) : XML::Node
    index += size if index < 0

    unless 0 <= index < size
      raise IndexError.new
    end

    internal_at(index)
  end

  def each(&) : Nil
    size.times do |i|
      yield internal_at(i)
    end
  end

  def empty? : Bool
    size == 0
  end

  # See `Object#hash(hasher)`
  def_hash object_id

  def inspect(io : IO) : Nil
    io << '['
    join io, ", ", &.inspect(io)
    io << ']'
  end

  def pretty_print(pp : PrettyPrint) : Nil
    pp.list("[", self, "]")
  end

  def size : Int32
    @set.value.node_nr
  end

  def object_id
    @set.address
  end

  def to_s(io : IO) : Nil
    join io, '\n'
  end

  def to_unsafe
    @set
  end

  private def internal_at(index)
    Node.new(@set.value.node_tab[index], @doc)
  end
end
