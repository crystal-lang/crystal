struct Set(T)
  include Enumerable(T)
  include Iterable

  def initialize
    @hash = Hash(T, Nil).new
  end

  def self.new(enumerable : Enumerable(T))
    set = Set(T).new
    enumerable.each do |elem|
      set << elem
    end
    set
  end

  def <<(object : T)
    add object
  end

  def add(object : T)
    @hash[object] = nil
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

  def size
    length
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
    self
  end

  def each
    @hash.each_key
  end

  def &(other : Set)
    set = Set(T).new
    each do |value|
      set.add value if other.includes?(value)
    end
    set
  end

  def |(other : Set(U))
    set = Set(T | U).new
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

  # Returns true if the set and the given set have at least one
  # element in common.
  #
  # ```
  # Set{1, 2, 3}.intersects? Set{4, 5} # => false
  # Set{1, 2, 3}.intersects? Set{3, 4} # => true
  # ```
  def intersects?(other : Set)
    if length < other.length
      any? { |o| other.includes?(o) }
    else
      other.any? { |o| includes?(o) }
    end
  end

  def to_s(io)
    io << "Set{"
    join ", ", io, &.inspect(io)
    io << "}"
  end

  def subset?(other : Set)
    return false if other.length < length
    all? { |value| other.includes?(value) }
  end

  def superset?(other : Set)
    return false if other.length > length
    other.all? { |value| includes?(value) }
  end

  def object_id
    @hash.object_id
  end

  def same?(other : Set)
    @hash.same?(other.@hash)
  end
end

class Array
  def to_set
    Set.new(self)
  end
end
