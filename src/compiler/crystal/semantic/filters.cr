module Crystal
  class TypeFilteredNode < ASTNode
    def initialize(@filter : TypeFilter, @node : ASTNode)
      @dependencies.push @node
      node.add_observer self
      update(@node)
    end

    def update(from = nil)
      from_type = from.try &.type?

      if from_type
        self.type = @filter.apply(from_type)
      end
    end

    def clone_without_location
      TypeFilteredNode.new(@filter, @node)
    end

    def to_s(io : IO) : Nil
      @filter.to_s(io)
    end
  end

  class ASTNode
    def filtered_by(filter)
      TypeFilteredNode.new(filter, self)
    end
  end

  abstract class TypeFilter
    def self.and(type_filter1, type_filter2)
      if type_filter1 == type_filter2
        type_filter1
      elsif type_filter1 && type_filter2
        AndTypeFilter.new(type_filter1, type_filter2)
      elsif type_filter1
        type_filter1
      elsif type_filter2
        type_filter2
      end
    end

    def self.or(type_filter1, type_filter2)
      if type_filter1 == type_filter2
        type_filter1
      elsif type_filter1 && type_filter2
        OrTypeFilter.new(type_filter1, type_filter2)
      end
    end

    def not
      NotFilter.new(self)
    end
  end

  class SimpleTypeFilter < TypeFilter
    getter type : Type

    def initialize(@type)
    end

    def apply(other)
      other.try &.filter_by(@type)
    end

    def ==(other : self)
      @type == other.type
    end

    def to_s(io : IO) : Nil
      io << "F("
      @type.to_s(io)
      io << ')'
    end
  end

  class AndTypeFilter < TypeFilter
    def initialize(@filter1 : TypeFilter, @filter2 : TypeFilter)
    end

    def apply(other)
      type = other
      type = @filter1.apply(type)
      type = @filter2.apply(type)
      type
    end

    def not
      # !(a && b) -> !a || !b
      TypeFilter.or(@filter1.not, @filter2.not)
    end

    def ==(other : self)
      @filter1 == other.@filter1 && @filter2 == other.@filter2
    end

    def to_s(io : IO) : Nil
      io << '(' << @filter1 << " && " << @filter2 << ')'
    end
  end

  class OrTypeFilter < TypeFilter
    def initialize(@filter1 : TypeFilter, @filter2 : TypeFilter)
    end

    def apply(other)
      type1 = @filter1.apply(other)
      type2 = @filter2.apply(other)
      res = if type1 && type2
              type1.program.type_merge_union_of([type1, type2])
            else
              type1 || type2
            end
      res
    end

    def not
      # !(a || b) -> !a && !b
      TypeFilter.and(@filter1.not, @filter2.not)
    end

    def ==(other : self)
      @filter1 == other.@filter1 && @filter2 == other.@filter2
    end

    def to_s(io : IO) : Nil
      io << '(' << @filter1 << " || " << @filter2 << ')'
    end
  end

  class TruthyFilter < TypeFilter
    INSTANCE = TruthyFilter.new

    def self.instance
      INSTANCE
    end

    def apply(other)
      return nil unless other

      case other
      when NilType
        nil
      when UnionType
        other.program.union_of(other.union_types.reject &.nil_type?)
      else
        other
      end
    end

    def ==(other : self)
      true
    end

    def to_s(io : IO) : Nil
      io << "truthy"
    end
  end

  class NotFilter < TypeFilter
    getter filter : TypeFilter

    def initialize(@filter : TypeFilter)
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

      # Special case: not truthy (falsey) can also be bool or pointer
      if @filter.is_a?(TruthyFilter)
        types.each do |type|
          if type.bool_type? || type.pointer?
            resulting_types << type
          end
        end
      end

      case resulting_types.size
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

    def not
      @filter
    end

    def ==(other : self)
      @filter == other.filter
    end

    def to_s(io : IO) : Nil
      io << '!'
      @filter.to_s(io)
    end
  end

  class RespondsToTypeFilter < TypeFilter
    def initialize(@name : String)
    end

    def apply(other)
      other.try &.filter_by_responds_to(@name)
    end

    def to_s(io : IO) : Nil
      io << "responds_to?(" << @name << ')'
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
    def initialize(@var : ASTNode)
    end

    def apply(other)
      other.try(&.no_return?) ? other : @var.type?
    end
  end

  struct TypeFilters
    protected getter pos = {} of String => TypeFilter
    protected getter neg = {} of String => TypeFilter

    protected def initialize
    end

    protected def initialize(*, @pos, @neg)
    end

    def self.new(node, filter)
      new_filters = new
      new_filters.pos[node.name] = filter
      new_filters.neg[node.name] = filter.not
      new_filters
    end

    def self.truthy(node)
      new node, TruthyFilter.instance
    end

    def self.and(filters1, filters2)
      return nil if filters1.nil? && filters2.nil?

      new_filters = new
      common_keys(filters1, filters2).each do |name|
        if filter = TypeFilter.and(filters1.try(&.pos[name]?), filters2.try(&.pos[name]?))
          new_filters.pos[name] = filter
        end
        if filter = TypeFilter.or(filters1.try(&.neg[name]?), filters2.try(&.neg[name]?))
          new_filters.neg[name] = filter
        end
      end
      new_filters
    end

    def self.or(filters1, filters2)
      return nil if filters1.nil? && filters2.nil?

      new_filters = new
      common_keys(filters1, filters2).each do |name|
        if filter = TypeFilter.or(filters1.try(&.pos[name]?), filters2.try(&.pos[name]?))
          new_filters.pos[name] = filter
        end
        if filter = TypeFilter.and(filters1.try(&.neg[name]?), filters2.try(&.neg[name]?))
          new_filters.neg[name] = filter
        end
      end
      new_filters
    end

    def self.not(filters)
      return nil if filters.nil?

      TypeFilters.new pos: filters.neg.dup, neg: filters.pos.dup
    end

    # If we have
    #
    #   if a = b
    #     ...
    #   end
    #
    # then `a` and `b` must have the same truthiness. Thus we can strengthen the
    # negation of the condition from `!a || !b` to `!a && !b`, which usually
    # provides a stricter filter.
    def self.assign_var(filters, target)
      if filters.nil?
        return truthy(target)
      end

      name = target.name
      filter = TruthyFilter.instance

      new_filters = filters.dup
      new_filters.pos[name] = TypeFilter.and(new_filters.pos[name]?, filter).not_nil!
      new_filters.neg[name] = TypeFilter.and(new_filters.neg[name]?, filter.not).not_nil!
      new_filters
    end

    def each(&)
      pos.each do |key, value|
        yield key, value
      end
    end

    def dup
      TypeFilters.new pos: pos.dup, neg: neg.dup
    end

    private def self.common_keys(filters1, filters2)
      keys = [] of String
      if filters1
        keys.concat(filters1.pos.keys)
        keys.concat(filters1.neg.keys)
      end
      if filters2
        keys.concat(filters2.pos.keys)
        keys.concat(filters2.neg.keys)
      end
      keys.uniq!
    end
  end
end
