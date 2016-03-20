class StringPool
  getter size : Int32
  @buckets : Array(Array(String)?)

  def initialize
    @buckets = Array(Array(String)?).new(11, nil)
    @size = 0
  end

  def empty?
    @size == 0
  end

  def get(slice : Slice(UInt8))
    get slice.pointer(slice.size), slice.size
  end

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

  def get(str : MemoryIO)
    get(str.buffer, str.bytesize)
  end

  def get(str : String)
    get(str.to_unsafe, str.bytesize)
  end

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
