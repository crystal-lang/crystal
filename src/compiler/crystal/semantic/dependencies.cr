require "./ast"

module Crystal
  # This is like an Array(ASTNode) except that it's optimized
  # for the case of having just one or two elements.
  class Dependencies
    include Enumerable(ASTNode)

    def initialize
      @first = nil
      @second = nil
      @all = nil
    end

    def initialize(node : ASTNode)
      @first = node
      @second = nil
      @all = nil
    end

    def each
      if all = @all
        all.each do |node|
          yield node
        end
      elsif second = @second
        yield @first.not_nil!
        yield second
      elsif first = @first
        yield first
      end
    end

    def push(node)
      if all = @all
        all.push node
      elsif second = @second
        all = @all = [@first.not_nil!, second, node] of ASTNode
        @first = nil
        @second = nil
      elsif @first
        @second = node
      else
        @first = node
      end
    end

    def concat(nodes)
      nodes.each do |node|
        push node
      end
    end

    def delete_if
      if all = @all
        all.delete_if do |node|
          yield node
        end
      elsif second = @second
        @second = nil if yield(second)
        first = @first.not_nil!
        @first = nil if yield(first)

        if @second && !@first
          @first = @second
          @second = nil
        end
      elsif first = @first
        @first = nil if yield(first)
      end
    end

    def length
      if all = @all
        all.length
      elsif @second
        2
      elsif @first
        1
      else
        0
      end
    end

    def two!
      if all = @all
        {all[0], all[1]}
      else
        {@first.not_nil!, @second.not_nil!}
      end
    end

    def inspect(io)
      to_s io
    end

    def to_s(io)
      io << "["
      each_with_index do |node, i|
        io << ", " if i > 0
        node.to_s(io)
      end
      io << "]"
    end
  end
end
