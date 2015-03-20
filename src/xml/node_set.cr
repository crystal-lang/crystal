module XML
  class NodeSet
    include Enumerable(Node)

    def initialize(@doc : Document, @set : LibXML::NodeSet*)
    end

    def length
      @set.value.node_nr
    end

    def empty?
      length == 0
    end

    def [](index : Int)
      index += length if index < 0

      unless 0 <= index < length
        raise IndexOutOfBounds.new
      end

      internal_at(index)
    end

    def each
      length.times do |i|
        yield internal_at(i)
      end
    end

    def to_unsafe
      @set
    end

    private def internal_at(index)
      Node.from_ptr(@set.value.node_tab[index]).not_nil!
    end
  end
end
