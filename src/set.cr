class Set(T)
  include Enumerable

  def initialize
    @hash = Hash(T, Bool).new
  end

  def self.new(array : Array(T))
    set = Set(T).new
    array.each do |elem|
      set << elem
    end
    set
  end

  def <<(object : T)
    add object
  end

  def add(object : T)
    @hash[object] = true
  end

  def merge(elems)
    elems.each { |elem| self << elem }
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

  def clear
    @hash.clear
    self
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

  def inspect(io)
    to_s(io)
  end

  def hash
    @hash.hash
  end

  def to_s(io)
    io << "Set{"
    join ", ", io, &.inspect(io)
    io << "}"
  end
end

class Array
  def to_set
    Set.new(self)
  end
end
