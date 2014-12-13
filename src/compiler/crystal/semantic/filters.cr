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

  class TruthyFilter < TypeFilter
    def self.instance
      @@instance
    end

    def apply(other)
      return nil unless other

      case other
      when NilType
        return nil
      when UnionType
        return Type.merge(other.union_types.reject &.nil_type?)
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

    @@instance = TruthyFilter.new
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

      # Special case: not truthy (falsey) can also be bool
      if @filter.is_a?(TruthyFilter) && (bool_type = types.find(&.bool_type?))
        resulting_types << bool_type
      end

      case resulting_types.length
      when 0
        if @filter.is_a?(TruthyFilter)
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

  # In code like:
  #
  #   x = 1
  #   if ...
  #     x = "hi"
  #     unreachable!
  #   end
  #
  # `x` type must be Int32 after the `if`, because the String type
  # doesn't matter afterwards as unreachable code comes. However, if
  # `unreachable!` is only temporarily unreachable (because of type propagation
  # that condition can change) we also want to bind `x` to String. But we
  # want to do that conditionally on the `if`'s `then` block being NoReturn or
  # not.
  #
  # This filter does that. It receives the var's type (String in this case)
  # and applies a filter to the `then` (or `else`) part of the `if`: if it's
  # no return, we return just that. If not, we return the var's type.
  class NoReturnFilter < TypeFilter
    def initialize(@var)
    end

    def apply(other)
      other.try(&.no_return?) ? other : @var.type?
    end
  end

  struct TypeFilters
    def initialize
      @filters = {} of String => TypeFilter
    end

    def self.new(node, filter)
      new_filter = new
      new_filter[node.name] = filter
      new_filter
    end

    def self.truthy(node)
      new node, TruthyFilter.instance
    end

    def self.and(filters1, filters2)
      if filters1 && filters2
        new_filters = TypeFilters.new
        all_keys = (filters1.keys + filters2.keys).uniq!
        all_keys.each do |name|
          filter1 = filters1[name]?
          filter2 = filters2[name]?
          if filter1 && filter2
            new_filters[name] = TypeFilter.and(filter1, filter2)
          elsif filter1
            new_filters[name] = filter1
          elsif filter2
            new_filters[name] = filter2
          end
        end
        new_filters
      elsif filters1
        filters1
      else
        filters2
      end
    end

    def self.and(filters1, filters2, filters3)
      and(filters1, and(filters2, filters3))
    end

    def [](name)
      @filters[name]
    end

    def []?(name)
      @filters[name]?
    end

    def []=(name, filter)
      @filters[name] = filter
    end

    def each
      @filters.each do |key, value|
        yield key, value
      end
    end

    def keys
      @filters.keys
    end
  end
end
