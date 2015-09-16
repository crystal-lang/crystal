# Set implements a collection of unordered values with no duplicates.
#
# An `Enumerable` object can be converted to `Set` using the `#to_set` method.
#
# Set uses `Hash` as storage, so you must note the following points:
#
# * Equality of elements is determined according to `Object#==` and
#   `Object#hash`.
# * Set assumes that the identity of each element does not change while it is
#   stored. Modifying an element of a set will render the set to an unreliable
#   state.
#
# ### Example
#
#     s1 = Set{1, 2}
#     s2 = [1, 2].to_set
#     s3 = Set.new [1, 2]
#     s1 == s2         # => true
#     s1 == s3         # => true
#     s1.add(2)
#     s1.merge([6,8])
#     s1.subset? s2    # => false
#     s2.subset? s1    # => true
struct Set(T)
  include Enumerable(T)
  include Iterable

  # Create a new, empty `Set`
  #
  #     s = Set(Int32).new
  #     set.empty? # => true
  def initialize
    @hash = Hash(T, Nil).new
  end

  # Creates a new set from the elements in `enumerable`
  #
  #     s = Set.new [1,3,5]
  #     s.empty? => false
  def self.new(enumerable : Enumerable(T))
    set = Set(T).new
    enumerable.each do |elem|
      set << elem
    end
    set
  end

  # Alias for `add`
  def <<(object : T)
    add object
  end

  # Adds `object` to the set and returns `self`
  #
  #     s = Set.new [1,5]
  #     s.includes? 8     # => false
  #     s << 8
  #     s.includes? 8     # => true
  def add(object : T)
    @hash[object] = nil
    self
  end

  # Adds `#each` element of `elms` to the set and returns `self`
  #
  #     s = Set.new [1,5]
  #     s.merge [5,5,8,9]
  #     s.size            # => 4
  def merge(elems)
    elems.each { |elem| self << elem }
    self
  end

  # Returns `true` if `object` exists in the set
  #
  #     s = Set.new [1,5]
  #     s.includes? 5  # => true
  #     s.includes? 9  # => false
  def includes?(object)
    @hash.has_key?(object)
  end

  # Removes the `object` from the set and returns `self`
  #
  #     s = Set.new [1,5]
  #     s.includes? 5  # => true
  #     s.delete 5
  #     s.includes? 5  # => false
  def delete(object)
    @hash.delete(object)
    self
  end

  # Returns the number of elements in the set
  #
  #     s = Set.new [1,5]
  #     s.size  # => 2
  def size
    @hash.size
  end

  # Removes all elements in the set, and returns `self`
  #
  #     s = Set.new [1,5]
  #     s.size  # => 2
  #     s.clear
  #     s.size  # => 0
  def clear
    @hash.clear
    self
  end

  # Returns `true` if the set is empty
  #
  #     s = Set(Int32).new
  #     s.empty? # => true
  #     s << 3
  #     s.empty? # => false
  def empty?
    @hash.empty?
  end

  # Yeilds each element of the set, and returns `self`
  def each
    @hash.each_key do |key|
      yield key
    end
    self
  end

  # Returns an iterator for each element of the set
  def each
    @hash.each_key
  end

  # Intersection: returns a new set containing elements common to both sets.
  #
  #     Set.new([1,1,3,5]) & Set.new([1,2,3])               #=> Set{1, 3}
  #     Set.new(['a','b','b','z']) & Set.new(['a','b','c']) #=> Set{'a', 'b'}
  def &(other : Set)
    set = Set(T).new
    each do |value|
      set.add value if other.includes?(value)
    end
    set
  end

  # Union: returns a new set containing all unique elements from both sets.
  #
  #     Set.new([1,1,3,5]) | Set.new([1,2,3])               #=> Set{1, 3, 5, 2}
  #     Set.new(['a','b','b','z']) | Set.new(['a','b','c']) #=> Set{'a', 'b', 'z', 'c'}
  def |(other : Set(U))
    set = Set(T | U).new
    each { |value| set.add value }
    other.each { |value| set.add value }
    set
  end

  # Returns `true` if both sets have the same elements
  #
  #     Set.new([1,5]) == Set.new([1,5]) # => true
  def ==(other : Set)
    same?(other) || @hash == other.@hash
  end

  # Returns a new set with all of the same elements
  def dup
    set = Set(T).new
    each { |value| set.add value }
    set
  end

  # Returns the elements as an array
  #
  #     Set.new([1,5]).to_a  # => [1,5]
  def to_a
    @hash.keys
  end

  # Alias of `#to_s`
  def inspect(io)
    to_s(io)
  end

  def hash
    @hash.hash
  end

  # Returns `true` if the set and the given set have at least one element in
  # common.
  #
  # ```
  # Set{1, 2, 3}.intersects? Set{4, 5} # => false
  # Set{1, 2, 3}.intersects? Set{3, 4} # => true
  # ```
  def intersects?(other : Set)
    if size < other.size
      any? { |o| other.includes?(o) }
    else
      other.any? { |o| includes?(o) }
    end
  end

  # Writes a string representation of the set to `io`
  def to_s(io)
    io << "Set{"
    join ", ", io, &.inspect(io)
    io << "}"
  end

  # Returns `true` if the set is a subset of the `other` set
  #
  # This set must have fewer elements than the `other` set, and all of elements
  # in this set must be present in the `other` set.
  #
  #     Set.new([1,5]).subset? Set.new([1,3,5]) # => true
  def subset?(other : Set)
    return false if other.size < size
    all? { |value| other.includes?(value) }
  end

  # Returns `true` if the set is a superset of the `other` set
  #
  # This set must have more elements than the `other` set, and all of elements
  # in the `other` set must be present in this set.
  #
  #     Set.new([1,3,5]).superset? Set.new([1,5]) # => true
  def superset?(other : Set)
    return false if other.size > size
    other.all? { |value| includes?(value) }
  end

  # :nodoc:
  def object_id
    @hash.object_id
  end

  # :nodoc:
  def same?(other : Set)
    @hash.same?(other.@hash)
  end
end

module Enumerable
  # Returns a new `Set` with each unique element in the enumerable
  def to_set
    Set.new(self)
  end
end
