class Set
  def initialize
    @hash = {}
  end

  def add(object)
    @hash[object] = true
  end

  def includes?(object)
    !!@hash[object]
  end

  def length
    @hash.length
  end

  def empty?
    @hash.empty?
  end
end