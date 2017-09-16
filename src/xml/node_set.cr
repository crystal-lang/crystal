struct XML::NodeSet
  include Enumerable(Node)

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

  def each : Nil
    size.times do |i|
      yield internal_at(i)
    end
  end

  def empty?
    size == 0
  end

  # See `Object#hash(hasher)`
  def_hash object_id

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
