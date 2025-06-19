struct XML::NodeSet
  include Enumerable(Node)

  # :nodoc:
  def self.new(set : LibXML::NodeSet*, document : Node)
    return NodeSet.new unless set || set.value.node_nr > 0

    nodes = Slice(Node).new(set.value.node_nr) do |i|
      Node.new(set.value.node_tab[i], document)
    end
    NodeSet.new(nodes)
  end

  @nodes : Slice(Node)

  # :nodoc:
  def initialize(nodes : Slice(Node)? = nil)
    @nodes = nodes || Slice(Node).new(0, Pointer(Void).null.as(Node))
  end

  def [](index : Int) : Node
    @nodes[index]
  end

  def each(&) : Nil
    @nodes.each { |node| yield node }
  end

  def empty? : Bool
    @nodes.empty?
  end

  def inspect(io : IO) : Nil
    io << '['
    join io, ", ", &.inspect(io)
    io << ']'
  end

  def pretty_print(pp : PrettyPrint) : Nil
    pp.list("[", self, "]")
  end

  def size : Int32
    @nodes.size
  end

  def to_s(io : IO) : Nil
    join io, '\n'
  end
end
