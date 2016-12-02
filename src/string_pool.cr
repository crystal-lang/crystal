# A string pool is a collection of strings.
# It allows a runtime to save memory by preserving strings in a pool, allowing to
# reuse an instance of a common string instead of creating a new one.
#
# ```
# require "string_pool"
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
  # Returns the size
  #
  # ```
  # pool = StringPool.new
  # pool.size # => 0
  # ```
  getter size : Int32

  # Creates a new empty string pool.
  def initialize
    @buckets = Array(Array(String)?).new(11, nil)
    @size = 0
  end

  # Returns `true` if the String Pool has no element otherwise returns `false`.
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

  # Returns a string with the contents of the given slice.
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
  def get(slice : Slice(UInt8))
    get slice.pointer(slice.size), slice.size
  end

  # Returns a string with the contents given by the pointer *str* of size *len*.
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
    rehash if @size > 5 * @buckets.size

    index = bucket_index str, len
    bucket = @buckets[index]

    if bucket
      entry = find_entry_in_bucket(bucket, str, len)
      if entry
        return entry
      end
    else
      @buckets[index] = bucket = Array(String).new
    end

    @size += 1
    entry = String.new(str, len)
    bucket.push entry
    entry
  end

  # Returns a string with the contents of the given `IO::Memory`.
  #
  # If a string with those contents was already present in the pool, that one is returned.
  # Otherwise a new string is created, put in the pool and returned
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

  # Returns a string with the contents of the given string.
  #
  # If a string with those contents was already present in the pool, that one is returned.
  # Otherwise a new string is created, put in the pool and returned
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
    new_size = calculate_new_size(@size)
    old_buckets = @buckets
    @buckets = Array(Array(String)?).new(new_size, nil)
    @size = 0

    old_buckets.each do |bucket|
      bucket.try &.each do |entry|
        get(entry.to_unsafe, entry.size)
      end
    end
  end

  private def bucket_index(str, len)
    hash = hash(str, len)
    (hash % @buckets.size).to_i
  end

  private def find_entry_in_bucket(bucket, str, len)
    bucket.each do |entry|
      if entry.size == len
        if str.memcmp(entry.to_unsafe, len) == 0
          return entry
        end
      end
    end
    nil
  end

  private def hash(str, len)
    h = 0
    str.to_slice(len).each do |c|
      h = 31 * h + c
    end
    h
  end

  private def calculate_new_size(size)
    new_size = 8
    Hash::HASH_PRIMES.each do |hash_size|
      return hash_size if new_size > size
      new_size <<= 1
    end
    raise "Hash table too big"
  end
end
