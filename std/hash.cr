require "array"
require "int"
require "nil"

class Hash(K, V)
  def initialize
    @buckets = Array(Array(Entry(K, V))?).new(17, nil)
    @length = 0
  end

  def []=(key : K, value : V)
    index = bucket_index key
    bucket = @buckets[index]

    if bucket
      entry = find_entry_in_bucket(bucket, key)
      if entry
        entry.value = value
        return value
      end
    else
      @buckets[index] = bucket = Array(Entry(K, V)).new
    end

    @length += 1
    entry = Entry(K, V).new(key, value)
    bucket.push entry
    @last.next = entry if @last
    @last = entry
    @first = entry unless @first
    value
  end

  def [](key)
    fetch(key)
  end

  def has_key?(key)
    !!find_entry(key)
  end

  def fetch(key)
    fetch(key) { raise "Missing value: #{key}" }
  end

  def fetch(key, default)
    fetch(key) { default }
  end

  def fetch(key)
    entry = find_entry(key)
    entry ? entry.value : yield key
  end

  def length
    @length
  end

  def empty?
    @length == 0
  end

  def each
    current = @first
    while current
      yield current.key, current.value
      current = current.next
    end
  end

  def keys
    keys = Array(K).new
    each { |key| keys << key }
    keys
  end

  def values
    values = Array(V).new
    each { |key, value| values << value }
    values
  end

  def ==(other : self)
    return false unless length == other.length
    each do |key, value|
      return false unless other[key] == value
    end
    true
  end

  def to_s
    String.build do |str|
      str << "{"
      found_one = false
      each do |key, value|
        str << ", " if found_one
        str << key.inspect
        str << " => "
        str << value.inspect
        found_one = true
      end
      str << "}"
    end
  end

  # private

  def find_entry(key)
    index = bucket_index key
    bucket = @buckets[index]
    bucket ? find_entry_in_bucket(bucket, key) : nil
  end

  def find_entry_in_bucket(bucket, key)
    bucket.each do |entry|
      if entry.key == key
        return entry
      end
    end
    nil
  end

  def bucket_index(key)
    key.hash % @buckets.length
  end

  class Entry(K, V)
    def initialize(key : K, value : V)
      @key = key
      @value = value
    end

    def key
      @key
    end

    def value
      @value
    end

    def value=(v : V)
      @value = v
    end

    def next
      @next
    end

    def next=(n)
      @next = n
    end
  end
end
