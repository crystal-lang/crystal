class Set(T)
  include Enumerable(T)
  include Iterable

  getter length

  def initialize
    @buckets = Pointer(Entry(T)?).malloc(11)
    @buckets_length = 11
    @length = 0
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
    rehash if @length > 5 * @buckets_length

    index = bucket_index object
    entry = insert_in_bucket index, object
    return nil unless entry

    @length += 1

    if last = @last
      last.fore = entry
      entry.back = last
    end

    @last = entry
    @first = entry unless @first
    nil
  end

  def merge(elems)
    elems.each { |elem| self << elem }
  end

  def includes?(object)
    !!find_entry(object)
  end

  protected def find_entry(object)
    index = bucket_index object
    entry = @buckets[index]
    find_entry_in_bucket entry, object
  end

  private def find_entry_in_bucket(entry, object)
    while entry
      if object == entry.object
        return entry
      end
      entry = entry.next
    end
    nil
  end

  private def insert_in_bucket(index, object)
    entry = @buckets[index]
    if entry
      while entry
        if object == entry.object
          return nil
        end
        if entry.next
          entry = entry.next
        else
          return entry.next = Entry(T).new(object)
        end
      end
    else
      return @buckets[index] = Entry(T).new(object)
    end
  end

  private def insert_in_bucket_end(index, existing_entry)
    entry = @buckets[index]
    if entry
      while entry
        if entry.next
          entry = entry.next
        else
          return entry.next = existing_entry
        end
      end
    else
      @buckets[index] = existing_entry
    end
  end

  private def bucket_index(object)
    (object.hash.abs % @buckets_length).to_i
  end

  private def calculate_new_size(size)
    new_size = 8
    HASH_PRIMES.each do |hash_size|
      return hash_size if new_size > size
      new_size <<= 1
    end
    raise "Hash table too big"
  end

  def delete(object)
    index = bucket_index(object)
    entry = @buckets[index]

    previous_entry = nil
    while entry
      if object == entry.object
        back_entry = entry.back
        fore_entry = entry.fore
        if fore_entry
          if back_entry
            back_entry.fore = fore_entry
            fore_entry.back = back_entry
          else
            @first = fore_entry
            fore_entry.back = nil
          end
        else
          if back_entry
            back_entry.fore = nil
            @last = back_entry
          else
            @first = nil
            @last = nil
          end
        end
        if previous_entry
          previous_entry.next = entry.next
        else
          @buckets[index] = entry.next
        end
        @length -= 1
        return nil
      end
      previous_entry = entry
      entry = entry.next
    end
    nil
  end

  def rehash
    new_size = calculate_new_size(@length)
    @buckets = @buckets.realloc(new_size)
    new_size.times { |i| @buckets[i] = nil }
    @buckets_length = new_size
    entry = @first
    while entry
      entry.next = nil
      index = bucket_index entry.object
      insert_in_bucket_end index, entry
      entry = entry.fore
    end
  end

  def size
    @length
  end

  def clear
    @buckets_length.times do |i|
      @buckets[i] = nil
    end
    @length = 0
    @first = nil
    @last = nil
    self
  end

  def empty?
    @length == 0
  end

  def each
    current = @first
    while current
      yield current.object
      current = current.fore
    end
    self
  end

  def each
    ObjectIterator(T).new(self, @first)
  end

  def &(other : Set)
    set = Set(T).new
    each do |object|
      set.add object if other.includes?(object)
    end
    set
  end

  def |(other : Set(U))
    set = Set(T | U).new
    each { |object| set.add object }
    other.each { |object| set.add object }
    set
  end

  def ==(other : Set)
    return false unless length == other.length
    each do |object|
      return false unless other.find_entry(object)
    end
    true
  end

  def dup
    set = Set(T).new
    each { |object| set.add object }
    set
  end

  def to_a
    objects = Array(T).new(@length)
    each { |object| objects << object }
    objects
  end

  def inspect(io)
    to_s(io)
  end

  def hash
    hash = length
    each do |object|
      hash = 31 * hash + object.hash
    end
    hash
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
    all? { |object| other.includes?(object) }
  end

  def superset?(other : Set)
    return false if other.length > length
    other.all? { |object| includes?(object) }
  end

  # :nodoc:
  class ObjectIterator(T)
    include Iterator(T)

    def initialize(@set, @current)
    end

    def next
      if current = @current
        object = current.object
        @current = current.fore
        object
      else
        stop
      end
    end

    def rewind
      @current = @set.@first
    end
  end

  # :nodoc:
  class Entry(T)
    getter :object

    # Next in the linked list of each bucket
    property :next

    # Next in the ordered sense of hash
    property :fore

    # Previous in the ordered sense of hash
    property :back

    def initialize(@object : T)
    end
  end


  # :nodoc:
  HASH_PRIMES = [
    8 + 3,
    16 + 3,
    32 + 5,
    64 + 3,
    128 + 3,
    256 + 27,
    512 + 9,
    1024 + 9,
    2048 + 5,
    4096 + 3,
    8192 + 27,
    16384 + 43,
    32768 + 3,
    65536 + 45,
    131072 + 29,
    262144 + 3,
    524288 + 21,
    1048576 + 7,
    2097152 + 17,
    4194304 + 15,
    8388608 + 9,
    16777216 + 43,
    33554432 + 35,
    67108864 + 15,
    134217728 + 29,
    268435456 + 3,
    536870912 + 11,
    1073741824 + 85,
    0
  ]
end

class Array
  def to_set
    Set.new(self)
  end
end
