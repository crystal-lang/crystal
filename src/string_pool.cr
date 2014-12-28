class StringPool
  getter length

  def initialize
    @buckets = Array(Array(String)?).new(11, nil)
    @length = 0
  end

  def empty?
    @length == 0
  end

  def get(slice : Slice(UInt8))
    get slice.pointer(slice.length), slice.length
  end

  def get(str : UInt8*, len)
    rehash if @length > 5 * @buckets.length

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

    @length += 1
    entry = String.new(str, len)
    bucket.push entry
    entry
  end

  def get(str : StringIO)
    get(str.buffer, str.bytesize)
  end

  def get(str : String)
    get(str.cstr, str.bytesize)
  end

  def rehash
    new_size = calculate_new_size(@length)
    old_buckets = @buckets
    @buckets = Array(Array(String)?).new(new_size, nil)
    @length = 0

    old_buckets.each do |bucket|
      bucket.try &.each do |entry|
        get(entry.cstr, entry.length)
      end
    end
  end

  private def bucket_index(str, len)
    hash = hash(str, len)
    (hash % @buckets.length).to_i
  end

  private def find_entry_in_bucket(bucket, str, len)
    bucket.each do |entry|
      if entry.length == len
        if str.memcmp(entry.cstr, len) == 0
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
