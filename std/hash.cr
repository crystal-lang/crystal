require "array"
require "int"
require "nil"

generic class Hash
  def initialize
    @buckets = Array.new(17, nil)
    @length = 0
  end

  def []=(key, value)
    index = bucket_index key
    unless bucket = @buckets[index]
      @buckets[index] = bucket = []
    end
    bucket.each do |entry|
      if key == entry.key
        return entry.value = value
      end
    end
    @length += 1
    entry = Entry.new(key, value)
    bucket.push entry
    @last.next = entry if @last
    @last = entry
    @first = entry unless @first
    value
  end

  def [](key)
    index = bucket_index key
    bucket = @buckets[index]
    return nil unless bucket

    bucket.each do |entry|
      if entry.key == key
        return entry.value
      end
    end

    nil
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
    keys = []
    each { |key| keys << key }
    keys
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

  generic class Entry
    def initialize(key, value)
      @key = key
      @value = value
    end

    def key
      @key
    end

    def value
      @value
    end

    def value=(v)
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