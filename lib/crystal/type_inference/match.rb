class Match
  attr_accessor :def
  attr_accessor :owner
  attr_accessor :type_lookup
  attr_accessor :arg_types
  attr_accessor :free_vars

  def initialize
    @arg_types = []
    @free_vars = {}
  end
end

class Matches
  include Enumerable

  attr_accessor :matches
  attr_accessor :cover
  attr_accessor :owner

  def initialize(matches, cover, owner = nil, success = true)
    @matches = matches
    @cover = cover
    @owner = owner
    @success = success
  end

  def cover_all?
    @success && @matches && @matches.length > 0 && (@cover == true || (@cover.is_a?(Cover) && @cover.all?))
  end

  def empty?
    !@success || !@matches || @matches.empty?
  end

  def each(&block)
    @matches.each(&block) if @success && @matches
  end
end