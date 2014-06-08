class Set(T)
  include Enumerable

  def initialize
    @hash = Hash(T, Bool).new
  end

  def initialize(array : Array(T))
    @hash = Hash(T, Bool).new
    array.each do |elem|
      add(elem)
    end
  end

  def <<(object : T)
    add(object)
  end

  def add(object : T)
    @hash[object] = true
  end

  def includes?(object)
    @hash.has_key?(object)
  end

  def delete(object)
    @hash.delete(object)
  end

  def length
    @hash.length
  end

  def empty?
    @hash.empty?
  end

  def each
    @hash.each_key do |key|
      yield key
    end
  end

  def &(other : Set)
    set = Set(T).new
    each do |value|
      set.add value if other.includes?(value)
    end
    set
  end

  def |(other : Set)
    set = Set(T).new
    each { |value| set.add value }
    other.each { |value| set.add value }
    set
  end

  def ==(other : Set)
    same?(other) || @hash == other.@hash
  end

  def dup
    set = Set(T).new
    each { |value| set.add value }
    set
  end

  def to_a
    @hash.keys
  end

  def inspect
    to_s
  end

  def to_s
    "Set{#{join ", "}}"
  end
end
