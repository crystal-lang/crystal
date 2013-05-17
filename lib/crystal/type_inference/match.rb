class Match
  attr_accessor :def
  attr_accessor :owner
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

  def initialize(matches, cover, owner = nil)
    @matches = matches
    @cover = cover
    @owner = owner
  end

  def cover_all?
    @matches && @matches.length > 0 && (@cover == true || (@cover.is_a?(Cover) && @cover.all?))
  end

  def empty?
    !@matches || @matches.empty?
  end

  def each(&block)
    @matches.each(&block) if @matches
  end

  def length
    @matches ? @matches.length : 0
  end
end