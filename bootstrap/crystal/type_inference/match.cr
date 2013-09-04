class Match
  property :def
  property :owner
  property :type_lookup
  property :arg_types
  property :free_vars

  def initialize(@owner, @def, @arg_types)
    # @arg_types = []
    # @free_vars = {}
  end
end

class Matches
  include Enumerable(Match)

  property :matches
  property :cover
  property :owner

  def initialize(@matches, @cover, @owner = nil, @success = true)
  end

  def each
    if @success && @matches
      @matches.each do |match|
        yield match
      end
    end
  end
end
