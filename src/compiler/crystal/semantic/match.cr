module Crystal
  class MatchContext
    property owner : Type
    property type_lookup : Type
    getter free_vars : Hash(String, Type)?
    getter? strict : Bool

    def initialize(@owner, @type_lookup, @free_vars = nil, @strict = false)
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
    getter def : Def
    getter arg_types : Array(Type)
    getter context : MatchContext

    def initialize(@def, @arg_types, @context)
    end
  end

  struct Matches
    include Enumerable(Match)

    property matches : Array(Match)?
    property cover : Bool | Cover | Nil
    property owner : Type?
    @success : Bool

    def initialize(@matches, @cover, @owner = nil, @success = true)
    end

    def cover_all?
      cover = @cover
      matches = @matches
      @success && matches && matches.size > 0 && (cover == true || (cover.is_a?(Cover) && cover.all?))
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

    def size
      @matches.try(&.size) || 0
    end
  end
end
