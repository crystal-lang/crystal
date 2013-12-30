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
    @hash.each do |key, value|
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
    same?(other) || internal_hash == other.internal_hash
  end

  def dup
    set = Set(T).new
    each { |value| set.add value }
    set
  end

  def to_a
    @hash.keys
  end

  def to_s
    "Set{#{join ", "}}"
  end

  # protected

  def internal_hash
    @hash
  end
end
