class Match
  attr_accessor :def
  attr_accessor :arg_types
  attr_accessor :free_vars

  def initialize
    @arg_types = []
    @free_vars = {}
  end
end