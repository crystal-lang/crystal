# A string pool is a collection of strings.
# It allows a runtime to save memory by preserving strings in a pool, allowing to
# reuse an instance of a common string instead of creating a new one.
#
# ```
# require "string_pool"
#
# pool = StringPool.new
# a = "foo" + "bar"
# b = "foo" + "bar"
# a.object_id # => 136294360
# b.object_id # => 136294336
# a = pool.get(a)
# b = pool.get(b)
# a.object_id # => 136294312
# b.object_id # => 136294312
# ```
class StringPool
  # Implementation uses open addressing scheme of hash table with [quadratic probing](https://en.wikipedia.org/wiki/Quadratic_probing).
  # Quadratic probing, using the triangular numbers, avoids the clumping while keeping
  # cache coherency in the common case.
  # As long as the table size is a power of 2, the quadratic-probing method [described by "Triangular numbers mod 2^n"](https://fgiesen.wordpress.com/2015/02/22/triangular-numbers-mod-2n/)
  # will explore every table element if necessary, to find a good place to insert.

  # Returns the size
  #
  # ```
  # pool = StringPool.new
  # pool.size # => 0
  # ```
  getter size : Int32

  # Creates a new empty string pool.
  def initialize
    @capacity = 8
    @hashes = Pointer(UInt64).malloc(@capacity, 0_u64)
    @values = Pointer(String).malloc(@capacity, "")
    @size = 0
  end

  # Returns `true` if the `StringPool` has no element otherwise returns `false`.
  #
  # ```
  # pool = StringPool.new
  # pool.empty? # => true
  # pool.get("crystal")
  # pool.empty? # => false
  # ```
  def empty?
    @size == 0
  end

  # Returns a `String` with the contents of the given *slice*.
  #
  # If a string with those contents was already present in the pool, that one is returned.
  # Otherwise a new string is created, put in the pool and returned.
  #
  # ```
  # pool = StringPool.new
  # ptr = Pointer.malloc(9) { |i| ('a'.ord + i).to_u8 }
  # slice = Slice.new(ptr, 3)
  # pool.empty? # => true
  # pool.get(slice)
  # pool.empty? # => false
  #  ```
  def get(slice : Bytes)
    get slice.pointer(slice.size), slice.size
  end

  # Returns a `String` with the contents given by the pointer *str* of size *len*.
  #
  # If a string with those contents was already present in the pool, that one is returned.
  # Otherwise a new string is created, put in the pool and returned.
  #
  # ```
  # pool = StringPool.new
  # pool.get("hey".to_unsafe, 3)
  # pool.size # => 1
  # ```
  def get(str : UInt8*, len)
    hash = hash(str, len)
    get(hash, str, len)
  end

  private def get(hash : UInt64, str : UInt8*, len)
    rehash if @size >= @capacity / 4 * 3

    mask = (@capacity - 1).to_u64
    index = hash & mask
    next_probe_offset = 1_u64
    while (h = @hashes[index]) != 0
      if h == hash && @values[index].bytesize == len
        if str.memcmp(@values[index].to_unsafe, len) == 0
          return @values[index]
        end
      end
      index = (index + next_probe_offset) & mask
      next_probe_offset += 1_u64
    end

    @size += 1
    entry = String.new(str, len)
    @hashes[index] = hash
    @values[index] = entry
    entry
  end

  private def put_on_rehash(hash : UInt64, entry : String)
    mask = (@capacity - 1).to_u64
    index = hash & mask
    next_probe_offset = 1_u64
    while @hashes[index] != 0
      index = (index + next_probe_offset) & mask
      next_probe_offset += 1_u64
    end

    @hashes[index] = hash
    @values[index] = entry
  end

  # Returns a `String` with the contents of the given `IO::Memory`.
  #
  # If a string with those contents was already present in the pool, that one is returned.
  # Otherwise a new string is created, put in the pool and returned.
  #
  # ```
  # pool = StringPool.new
  # io = IO::Memory.new "crystal"
  # pool.empty? # => true
  # pool.get(io)
  # pool.empty? # => false
  # ```
  def get(str : IO::Memory)
    get(str.buffer, str.bytesize)
  end

  # Returns a `String` with the contents of the given string.
  #
  # If a string with those contents was already present in the pool, that one is returned.
  # Otherwise a new string is created, put in the pool and returned.
  #
  # ```
  # pool = StringPool.new
  # string = "crystal"
  # pool.empty? # => true
  # pool.get(string)
  # pool.empty? # => false
  # ```
  def get(str : String)
    get(str.to_unsafe, str.bytesize)
  end

  # Rebuilds the hash based on the current hash values for each key,
  # if values of key objects have changed since they were inserted.
  #
  # Call this method if you modified a string submitted to the pool.
  def rehash
    if @capacity * 2 <= 0
      raise "Hash table too big"
    end

    old_capacity = @capacity
    old_hashes = @hashes
    old_values = @values

    @capacity *= 2
    @hashes = Pointer(UInt64).malloc(@capacity, 0_u64)
    @values = Pointer(String).malloc(@capacity, "")

    old_capacity.times do |i|
      if old_hashes[i] != 0
        put_on_rehash(old_hashes[i], old_values[i])
      end
    end
  end

  private def hash(str, len)
    hasher = Crystal::Hasher.new
    hasher = str.to_slice(len).hash(hasher)
    # hash should be non-zero, so `or` it with high bit
    hasher.result | 0x8000000000000000_u64
  end
end
