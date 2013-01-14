generic class Set
  include Enumerable

  def initialize
    @hash = {}
  end

  def initialize(array : Array)
    @hash = {}
    array.each do |elem|
      add(elem)
    end
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

  def each
    @hash.each do |key, value|
      yield key
    end
  end

  def to_s
    "Set{#{join ", "}}"
  end
end