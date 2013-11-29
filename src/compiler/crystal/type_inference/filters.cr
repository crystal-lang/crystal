module Crystal
  class TypeFilteredNode < ASTNode
    def initialize(@filter)
    end

    def bind_to(node : ASTNode)
      @node = node
      node.add_observer self
      update(node)
    end

    def update(from)
      from_type = from.type?

      if from_type
        self.type = @filter.apply(from_type)
      end
    end

    def clone_without_location
      TypeFilteredNode.new(@filter)
    end

    def to_s
      @filter.to_s
    end
  end

  abstract class TypeFilter
  end

  class SimpleTypeFilter < TypeFilter
    getter type

    def initialize(@type)
    end

    def apply(other)
      other.try &.filter_by(@type)
    end

    def ==(other : self)
      @type == other.type
    end

    def to_s
      "F(#{@type})"
    end
  end

  class AndTypeFilter < TypeFilter
    getter filters

    def initialize(filters)
      @filters = Set(TypeFilter).new(filters)
    end

    def apply(other)
      type = other
      @filters.each do |filter|
        type = filter.apply(type)
      end
      type
    end

    def ==(other : self)
      @filters == other.filters
    end

    def to_s
      "(#{@filters.join " && "})"
    end
  end

  class NotNilFilter < TypeFilter
    def self.instance
      @@instance
    end

    def apply(other)
      return nil unless other

      case other
      when NilType
        return nil
      when UnionType
        return Type.merge(other.union_types.select { |type| !type.nil_type? })
      else
        other
      end
    end

    def ==(other : self)
      true
    end

    def to_s
      "!F(Nil)"
    end

    @@instance = NotNilFilter.new
  end

  class NotFilter < TypeFilter
    getter filter

    def initialize(filter)
      @filter = filter
    end

    def apply(other)
      types = @filter.apply(other)

      if types
        types = [types] of Type unless types.is_a?(Array)
      else
        types = [] of Type
      end

      if other.is_a?(UnionType)
        other_types = other.union_types
      else
        other_types = other ? [other] of Type : [] of Type
      end

      resulting_types = other_types - types
      case resulting_types.length
      when 0
        # TODO: should be nil?
        other
      when 1
        resulting_types.first
      else
        Type.merge(resulting_types)
      end
    end

    def ==(other : self)
      @filter == other.filter
    end

    def to_s
      "!#{@filter}"
    end
  end

  class RespondsToTypeFilter < TypeFilter
    def initialize(@name)
    end

    def apply(other)
      other.try &.filter_by_responds_to(@name)
    end

    def to_s
      "responds_to?(#{@name})"
    end
  end
end
