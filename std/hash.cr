require "array"
require "int"
require "nil"

class Hash(K, V)
  def initialize(block = nil)
    @buckets = Array(Array(Entry(K, V))?).new(17, nil)
    @length = 0
    @block = block
  end

  def self.new(&block : Hash(K, V), K -> V)
    hash = allocate
    hash.initialize(block)
    hash
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

    if @last
      @last.next = entry
      entry.previous = @last
    end

    @last = entry
    @first = entry unless @first
    value
  end

  def [](key)
    fetch(key)
  end

  def []?(key)
    fetch(key, nil)
  end

  def has_key?(key)
    !!find_entry(key)
  end

  def fetch(key)
    fetch(key) do
      if @block
        @block.call(self, key)
      else
        raise "Missing hash value: #{key}"
      end
    end
  end

  def fetch(key, default)
    fetch(key) { default }
  end

  def fetch(key)
    entry = find_entry(key)
    entry ? entry.value : yield key
  end

  def delete(key)
    index = bucket_index(key)
    bucket = @buckets[index]
    if bucket
      bucket.delete_if do |entry|
        if entry.key == key
          previous_entry = entry.previous
          next_entry = entry.next
          if next_entry
            if previous_entry
              previous_entry.next = next_entry
              next_entry.previous = previous_entry
            else
              @first = next_entry
              next_entry.previous = nil
            end
          else
            if previous_entry
              previous_entry.next = nil
              @last = previous_entry
            else
              @first = nil
              @last = nil
            end
          end
          @length -= 1
          true
        else
          false
        end
      end
    end
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

  def map(&block : K, V -> U)
    array = Array(U).new(@length)
    each do |k, v|
      array.push yield k, v
    end
    array
  end

  def merge(other : Hash(K2, V2))
    hash = Hash(K | K2, V | V2).new
    each do |k, v|
      hash[k] = v
    end
    other.each do |k, v|
      hash[k] = v
    end
    hash
  end

  def self.zip(ary1 : Array(K), ary2 : Array(V))
    hash = {} of K => V
    ary1.each_with_index do |key, i|
      hash[key] = ary2[i]
    end
    hash
  end

  def first_key
    @first.not_nil!.key
  end

  def first_key?
    @first ? @first.key : nil
  end

  def first_value
    @first.not_nil!.value
  end

  def first_value?
    @first ? @first.value : nil
  end

  def ==(other : self)
    return false unless length == other.length
    each do |key, value|
      return false unless other[key] == value
    end
    true
  end

  def clone
    hash = Hash(K, V).new
    each do |key, value|
      hash[key] = value.clone
    end
    hash
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
    (key.hash % @buckets.length).to_i
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

    def previous
      @previous
    end

    def previous=(p)
      @previous = p
    end
  end
end
