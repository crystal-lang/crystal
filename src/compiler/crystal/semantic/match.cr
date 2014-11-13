module Crystal
  class MatchContext
    getter owner
    getter type_lookup
    getter free_vars

    def initialize(@owner, @type_lookup, @free_vars = nil)
    end

    def get_free_var(name)
      @free_vars.try &.[name]?
    end

    def set_free_var(name, type)
      free_vars = @free_vars ||= {} of String => Type
      free_vars[name] = type
    end

    def clone
      MatchContext.new(@owner, @type_lookup, @free_vars.clone)
    end
  end

  class Match
    getter :def
    getter :arg_types
    getter :context

    def initialize(@def, @arg_types, @context)
    end
  end

  struct Matches
    include Enumerable(Match)

    property :matches
    property :cover
    property :owner

    def initialize(@matches, @cover, @owner = nil, @success = true)
    end

    def cover_all?
      cover = @cover
      matches = @matches
      @success && matches && matches.length > 0 && (cover == true || (cover.is_a?(Cover) && cover.all?))
    end

    def empty?
      return true unless @success

      if matches = @matches
        matches.empty?
      else
        true
      end
    end

    def each
      @success && @matches.try &.each do |match|
        yield match
      end
    end

    def length
      @matches.try(&.length) || 0
    end
  end
end
