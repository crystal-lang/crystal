struct XML::NodeSet
  include Enumerable(Node)

  @doc : Node
  @set : LibXML::NodeSet*

  def initialize(@doc : Node, @set : LibXML::NodeSet*)
  end

  def self.new(doc : Node)
    new doc, LibXML.xmlXPathNodeSetCreate(nil)
  end

  def [](index : Int)
    index += size if index < 0

    unless 0 <= index < size
      raise IndexError.new
    end

    internal_at(index)
  end

  def each
    size.times do |i|
      yield internal_at(i)
    end
  end

  def empty?
    size == 0
  end

  def hash
    object_id
  end

  def inspect(io)
    io << "["
    join ", ", io, &.inspect(io)
    io << "]"
  end

  def size
    @set.value.node_nr
  end

  def object_id
    @set.address
  end

  def to_s(io)
    join "\n", io
  end

  def to_unsafe
    @set
  end

  private def internal_at(index)
    Node.new(@set.value.node_tab[index])
  end
end
