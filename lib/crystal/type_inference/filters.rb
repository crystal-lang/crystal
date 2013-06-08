module Crystal
  class TypeFilteredNode < ASTNode
    def initialize(filter)
      @filter = filter
    end

    def bind_to(node)
      @node = node
      node.add_observer self
      update(node)
    end

    def update(from)
      self.type = @filter.apply(from.type) if from.type
    end

    def real_type
      @node.real_type
    end

    def to_s
      @filter.to_s
    end
  end

  class SimpleTypeFilter
    def initialize(type)
      @type = type
    end

    def apply(other)
      other.filter_by(@type)
    end

    def to_s
      "F(#{@type})"
    end
  end

  class AndTypeFilter
    def initialize(filter1, filter2)
      @filter1 = filter1
      @filter2 = filter2
    end

    def apply(other)
      @filter2.apply(@filter1.apply(other))
    end

    def to_s
      "(#{@filter1} && #{@filter2})"
    end
  end

  class NotNilFilter
    def self.apply(other)
      return nil if other.nil_type?

      if other.is_a?(UnionType)
        return Type.merge(*other.types.select { |type| !type.nil_type? })
      end

      other
    end
  end
end
