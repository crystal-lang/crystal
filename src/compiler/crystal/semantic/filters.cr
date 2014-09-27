module Crystal
  class TypeFilteredNode < ASTNode
    def initialize(@filter, @node)
      @dependencies = Dependencies.new(@node)
      node.add_observer self
      update(@node)
    end

    def update(from)
      from_type = from.type?

      if from_type
        self.type = @filter.apply(from_type)
      end
    end

    def clone_without_location
      TypeFilteredNode.new(@filter, @node)
    end

    def to_s(io)
      @filter.to_s(io)
    end
  end

  class ASTNode
    def filtered_by(filter)
      TypeFilteredNode.new(filter, self)
    end
  end

  abstract class TypeFilter
    def self.and(filters)
      set = Set.new(filters)
      uniq = set.to_a
      if uniq.length == 1
        return uniq.first
      else
        AndTypeFilter.new(uniq)
      end
    end

    def self.and(type_filter1, type_filter2)
      if type_filter1 == type_filter2
        return type_filter1
      else
        AndTypeFilter.new([type_filter1, type_filter2])
      end
    end

    def not
      NotFilter.new(self)
    end
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

    def to_s(io)
      io << "F("
      @type.to_s(io)
    end
  end

  class AndTypeFilter < TypeFilter
    getter filters

    def initialize(filters)
      @filters = filters
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

    def to_s(io)
      io << "("
      @filters.join " && ", io
      io << ")"
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

    def to_s(io)
      io << "not-nil"
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
        case types
        when UnionType
          types = types.union_types
        when Array
          types
        else
          types = [types] of Type
        end
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
        if @filter.is_a?(NotNilFilter)
          other
        else
          nil
        end
      when 1
        resulting_types.first
      else
        Type.merge(resulting_types)
      end
    end

    def ==(other : self)
      @filter == other.filter
    end

    def to_s(io)
      io << "!"
      @filter.to_s(io)
    end
  end

  class RespondsToTypeFilter < TypeFilter
    def initialize(@name)
    end

    def apply(other)
      other.try &.filter_by_responds_to(@name)
    end

    def to_s(io)
      io << "responds_to?("
      @name.to_s(io)
      io << ")"
    end
  end
end
