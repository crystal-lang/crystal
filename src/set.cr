# `Set` implements a collection of unordered values with no duplicates.
#
# An `Enumerable` object can be converted to `Set` using the `#to_set` method.
#
# `Set` uses `Hash` as storage, so you must note the following points:
#
# * Equality of elements is determined according to `Object#==` and `Object#hash`.
# * `Set` assumes that the identity of each element does not change while it is stored. Modifying an element of a set will render the set to an unreliable state.
#
# ### Example
#
# ```
# s1 = Set{1, 2}
# s2 = [1, 2].to_set
# s3 = Set.new [1, 2]
# s1 == s2 # => true
# s1 == s3 # => true
# s1.add(2)
# s1.concat([6, 8])
# s1.subset? s2 # => false
# s2.subset? s1 # => true
# ```
struct Set(T)
  include Enumerable(T)
  include Iterable(T)

  # Creates a new, empty `Set`.
  #
  # ```
  # s = Set(Int32).new
  # s.empty? # => true
  # ```
  #
  # An initial capacity can be specified, and it will be set as the initial capacity
  # of the internal `Hash`.
  def initialize(initial_capacity = nil)
    @hash = Hash(T, Nil).new(initial_capacity: initial_capacity)
  end

  # Optimized version of `new` used when *other* is also an `Indexable`
  def self.new(other : Indexable(T))
    Set(T).new(other.size).concat(other)
  end

  # Creates a new set from the elements in *enumerable*.
  #
  # ```
  # a = [1, 3, 5]
  # s = Set.new a
  # s.empty? # => false
  # ```
  def self.new(enumerable : Enumerable(T))
    Set(T).new.concat(enumerable)
  end

  # Alias for `add`
  def <<(object : T)
    add object
  end

  # Adds *object* to the set and returns `self`.
  #
  # ```
  # s = Set{1, 5}
  # s.includes? 8 # => false
  # s << 8
  # s.includes? 8 # => true
  # ```
  def add(object : T)
    @hash[object] = nil
    self
  end

  # Adds `#each` element of *elems* to the set and returns `self`.
  #
  # ```
  # s = Set{1, 5}
  # s.concat [5, 5, 8, 9]
  # s.size # => 4
  # ```
  #
  # See also: `#|` to merge two sets and return a new one.
  def concat(elems)
    elems.each { |elem| self << elem }
    self
  end

  # Returns `true` if *object* exists in the set.
  #
  # ```
  # s = Set{1, 5}
  # s.includes? 5 # => true
  # s.includes? 9 # => false
  # ```
  def includes?(object)
    @hash.has_key?(object)
  end

  # Removes the *object* from the set and returns `self`.
  #
  # ```
  # s = Set{1, 5}
  # s.includes? 5 # => true
  # s.delete 5
  # s.includes? 5 # => false
  # ```
  def delete(object)
    @hash.delete(object)
    self
  end

  # Returns the number of elements in the set.
  #
  # ```
  # s = Set{1, 5}
  # s.size # => 2
  # ```
  def size
    @hash.size
  end

  # Removes all elements in the set, and returns `self`.
  #
  # ```
  # s = Set{1, 5}
  # s.size # => 2
  # s.clear
  # s.size # => 0
  # ```
  def clear
    @hash.clear
    self
  end

  # Returns `true` if the set is empty.
  #
  # ```
  # s = Set(Int32).new
  # s.empty? # => true
  # s << 3
  # s.empty? # => false
  # ```
  def empty?
    @hash.empty?
  end

  # Yields each element of the set, and returns `self`.
  def each
    @hash.each_key do |key|
      yield key
    end
  end

  # Returns an iterator for each element of the set.
  def each
    @hash.each_key
  end

  # Intersection: returns a new set containing elements common to both sets.
  #
  # ```
  # Set{1, 1, 3, 5} & Set{1, 2, 3}               # => Set{1, 3}
  # Set{'a', 'b', 'b', 'z'} & Set{'a', 'b', 'c'} # => Set{'a', 'b'}
  # ```
  def &(other : Set)
    smallest, largest = self, other
    if largest.size < smallest.size
      smallest, largest = largest, smallest
    end

    set = Set(T).new
    smallest.each do |value|
      set.add value if largest.includes?(value)
    end
    set
  end

  # Union: returns a new set containing all unique elements from both sets.
  #
  # ```
  # Set{1, 1, 3, 5} | Set{1, 2, 3}               # => Set{1, 3, 5, 2}
  # Set{'a', 'b', 'b', 'z'} | Set{'a', 'b', 'c'} # => Set{'a', 'b', 'z', 'c'}
  # ```
  #
  # See also: `#concat` to add elements from a set to `self`.
  def |(other : Set(U)) forall U
    set = Set(T | U).new(Math.max(size, other.size))
    each { |value| set.add value }
    other.each { |value| set.add value }
    set
  end

  # Difference: returns a new set containing elements in this set that are not
  # present in the other.
  #
  # ```
  # Set{1, 2, 3, 4, 5} - Set{2, 4}               # => Set{1, 3, 5}
  # Set{'a', 'b', 'b', 'z'} - Set{'a', 'b', 'c'} # => Set{'z'}
  # ```
  def -(other : Set)
    set = Set(T).new
    each do |value|
      set.add value unless other.includes?(value)
    end
    set
  end

  # Difference: returns a new set containing elements in this set that are not
  # present in the other enumerable.
  #
  # ```
  # Set{1, 2, 3, 4, 5} - [2, 4]               # => Set{1, 3, 5}
  # Set{'a', 'b', 'b', 'z'} - ['a', 'b', 'c'] # => Set{'z'}
  # ```
  def -(other : Enumerable)
    dup.subtract other
  end

  # Symmetric Difference: returns a new set `(self - other) | (other - self)`.
  # Equivalently, returns `(self | other) - (self & other)`.
  #
  # ```
  # Set{1, 2, 3, 4, 5} ^ Set{2, 4, 6}            # => Set{1, 3, 5, 6}
  # Set{'a', 'b', 'b', 'z'} ^ Set{'a', 'b', 'c'} # => Set{'z', 'c'}
  # ```
  def ^(other : Set(U)) forall U
    set = Set(T | U).new
    each do |value|
      set.add value unless other.includes?(value)
    end
    other.each do |value|
      set.add value unless includes?(value)
    end
    set
  end

  # Symmetric Difference: returns a new set `(self - other) | (other - self)`.
  # Equivalently, returns `(self | other) - (self & other)`.
  #
  # ```
  # Set{1, 2, 3, 4, 5} ^ [2, 4, 6]            # => Set{1, 3, 5, 6}
  # Set{'a', 'b', 'b', 'z'} ^ ['a', 'b', 'c'] # => Set{'z', 'c'}
  # ```
  def ^(other : Enumerable(U)) forall U
    set = Set(T | U).new(self)
    other.each do |value|
      if includes?(value)
        set.delete value
      else
        set.add value
      end
    end
    set
  end

  # Returns `self` after removing from it those elements that are present in
  # the given enumerable.
  #
  # ```
  # Set{'a', 'b', 'b', 'z'}.subtract Set{'a', 'b', 'c'} # => Set{'z'}
  # Set{1, 2, 3, 4, 5}.subtract [2, 4, 6]               # => Set{1, 3, 5}
  # ```
  def subtract(other : Enumerable)
    other.each do |value|
      delete value
    end
    self
  end

  # Returns `true` if both sets have the same elements.
  #
  # ```
  # Set{1, 5} == Set{1, 5} # => true
  # ```
  def ==(other : Set)
    same?(other) || @hash == other.@hash
  end

  # Returns a new `Set` with all of the same elements.
  def dup
    Set.new(self)
  end

  # Returns a new `Set` with all of the elements cloned.
  def clone
    clone = Set(T).new(self.size)
    each do |element|
      clone << element.clone
    end
    clone
  end

  # Returns the elements as an `Array`.
  #
  # ```
  # Set{1, 5}.to_a # => [1,5]
  # ```
  def to_a
    @hash.keys
  end

  # Alias of `#to_s`.
  def inspect(io)
    to_s(io)
  end

  def pretty_print(pp) : Nil
    pp.list("Set{", self, "}")
  end

  # See `Object#hash(hasher)`
  def_hash @hash

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

  # Writes a string representation of the set to *io*.
  def to_s(io)
    io << "Set{"
    join ", ", io, &.inspect(io)
    io << "}"
  end

  # Returns `true` if the set is a subset of the *other* set.
  #
  # This set must have the same or fewer elements than the *other* set, and all
  # of elements in this set must be present in the *other* set.
  #
  # ```
  # Set{1, 5}.subset? Set{1, 3, 5}    # => true
  # Set{1, 3, 5}.subset? Set{1, 3, 5} # => true
  # ```
  def subset?(other : Set)
    return false if other.size < size
    all? { |value| other.includes?(value) }
  end

  # Returns `true` if the set is a proper subset of the *other* set.
  #
  # This set must have fewer elements than the *other* set, and all
  # of elements in this set must be present in the *other* set.
  #
  # ```
  # Set{1, 5}.proper_subset? Set{1, 3, 5}    # => true
  # Set{1, 3, 5}.proper_subset? Set{1, 3, 5} # => false
  # ```
  def proper_subset?(other : Set)
    return false if other.size <= size
    all? { |value| other.includes?(value) }
  end

  # Returns `true` if the set is a superset of the *other* set.
  #
  # The *other* must have the same or fewer elements than this set, and all of
  # elements in the *other* set must be present in this set.
  #
  # ```
  # Set{1, 3, 5}.superset? Set{1, 5}    # => true
  # Set{1, 3, 5}.superset? Set{1, 3, 5} # => true
  # ```
  def superset?(other : Set)
    other.subset?(self)
  end

  # Returns `true` if the set is a superset of the *other* set.
  #
  # The *other* must have the same or fewer elements than this set, and all of
  # elements in the *other* set must be present in this set.
  #
  # ```
  # Set{1, 3, 5}.proper_superset? Set{1, 5}    # => true
  # Set{1, 3, 5}.proper_superset? Set{1, 3, 5} # => false
  # ```
  def proper_superset?(other : Set)
    other.proper_subset?(self)
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
  # Returns a new `Set` with each unique element in the enumerable.
  def to_set
    Set.new(self)
  end
end
