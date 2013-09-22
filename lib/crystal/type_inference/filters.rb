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

    def to_s
      @filter.to_s
    end
  end

  class SimpleTypeFilter
    def initialize(type)
      @type = type
    end

    def apply(other)
      other ? other.filter_by(@type) : nil
    end

    def to_s
      "F(#{@type})"
    end
  end

  class AndTypeFilter
    def initialize(*filters)
      @filters = filters.uniq
    end

    def apply(other)
      type = other
      @filters.each do |filter|
        type = filter.apply(type)
      end
      type
    end

    def to_s
      "(#{@filters.join ' && '})"
    end
  end

  class NotNilFilter
    def self.apply(other)
      return nil if !other || other.nil_type?

      if other.is_a?(UnionType)
        return Type.merge(*other.types.select { |type| !type.nil_type? })
      end

      other
    end
  end

  class NotFilter
    def initialize(filter)
      @filter = filter
    end

    def apply(other)
      types = @filter.apply(other)
      types = [types] unless types.is_a?(Array)

      if other.is_a?(UnionType)
        other_types = other.types
      else
        other_types = [other]
      end

      resulting_types = other_types - types
      case resulting_types.length
      when 0
        # TODO: should be nil?
        other
      when 1
        resulting_types.first
      else
        Type.merge(*resulting_types)
      end
    end

    def to_s
      "Not(#{@filter})"
    end
  end

  class RespondsToTypeFilter
    def initialize(name)
      @name = name
    end

    def apply(other)
      other.filter_by_responds_to(@name)
    end

    def to_s
      "responds_to?(#{@name})"
    end
  end
end
