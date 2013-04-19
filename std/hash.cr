require "array"
require "int"
require "nil"

class Hash(K, V)
  def initialize
    @buckets = Array(Array(Entry(K, V)) | Nil).new(17, nil)
    @length = 0
  end

  def []=(key : K, value : V)
    index = bucket_index key
    if (bucket = @buckets[index]).nil?
      @buckets[index] = bucket = Array(Entry(K, V)).new
    end
    bucket.each do |entry|
      if key == entry.key
        return entry.value = value
      end
    end
    @length += 1
    entry = Entry(K, V).new(key, value)
    bucket.push entry
    @last.next = entry unless @last.nil?
    @last = entry
    @first = entry if @first.nil?
    value
  end

  def [](key)
    fetch key
  end

  def fetch(key)
    fetch key, nil
  end

  def fetch(key, default)
    index = bucket_index key
    bucket = @buckets[index]
    return default unless bucket

    bucket.each do |entry|
      if entry.key == key
        return entry.value
      end
    end

    default
  end

  def fetch(key)
    index = bucket_index key
    bucket = @buckets[index]
    return yield key unless bucket

    bucket.each do |entry|
      if entry.key == key
        return entry.value
      end
    end

    yield key
  end

  def length
    @length
  end

  def empty?
    @length == 0
  end

  def each
    current = @first
    while !current.nil?
      yield current.key, current.value
      current = current.next
    end
  end

  def keys
    keys = Array(K).new
    each { |key| keys << key }
    keys
  end

  def ==(other : self)
    return false unless length == other.length
    each do |key, value|
      return false unless other[key] == value
    end
    true
  end

  def to_s
    str = StringBuilder.new
    str << "{"
    found_one = false
    each do |key, value|
      str << ", " if found_one
      str << key.inspect
      str << "=>"
      str << value.inspect
      found_one = true
    end
    str << "}"
    str.to_s
  end

  # private

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