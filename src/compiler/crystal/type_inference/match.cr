module Crystal
  class Match
    getter :def
    getter :owner
    getter :type_lookup
    getter :arg_types
    getter :free_vars

    def initialize(@owner, @def, @type_lookup, @arg_types, @free_vars = {} of String => Type)
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
      @success && @matches && @matches.length > 0 && (cover == true || (cover.is_a?(Cover) && cover.all?))
    end

    def empty?
      !@success || !@matches || @matches.empty?
    end

    def each
      if @success && @matches
        @matches.each do |match|
          yield match
        end
      end
    end

    def first
      @matches.first
    end

    def length
      @matches.length
    end
  end
end
