module Crystal
  class Match
    getter :def
    getter :owner
    property :type_lookup
    getter :arg_types
    getter :free_vars

    def initialize(@owner, @def, @arg_types)
      @free_vars = {} of String => Type
    end
  end

  class Matches
    include Enumerable(Match)

    property :matches
    property :cover
    property :owner

    def initialize(@matches, @cover, @owner = nil, @success = true)
    end

    def empty?
      !@success || @matches.empty?
    end

    def cover_all?
      !empty?
    end

    def each
      if @success && @matches
        @matches.each do |match|
          yield match
        end
      end
    end
  end
end
