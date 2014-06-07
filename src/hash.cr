require "object"
require "array"
require "int"
require "nil"

class Hash(K, V)
  module StandardComparator
    def self.hash(object)
      object.hash
    end

    def self.equals?(o1, o2)
      o1 == o2
    end
  end

  module CaseInsensitiveComparator
    def self.hash(str : String)
      str.downcase.hash
    end

    def self.equals?(str1 : String, str2 : String)
      str1.downcase == str2.downcase
    end

    def self.hash(object)
      object.hash
    end

    def self.equals?(o1, o2)
      o1 == o2
    end
  end

  def initialize(block = nil, @comp = StandardComparator)
    @buckets = Array(Entry(K, V)?).new(11, nil)
    @length = 0
    @block = block
  end

  def self.new(block : Hash(K, V), K -> V)
    hash = allocate
    hash.initialize(block)
    hash
  end

  def []=(key : K, value : V)
    rehash if @length > 5 * @buckets.length

    index = bucket_index key
    entry = insert_in_bucket index, key, value
    return value unless entry

    @length += 1

    if last = @last
      last.fore = entry
      entry.back = last
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
      if block = @block
        block.call(self, key)
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
    entry = @buckets[index]

    previous_entry = nil
    while entry
      if @comp.equals?(entry.key, key)
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
        return true
      end
      previous_entry = entry
      entry = entry.next
    end
    false
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
      current = current.fore
    end
    self
  end

  def each_key
    each do |key, value|
      yield key
    end
  end

  def each_value
    each do |key, value|
      yield value
    end
  end

  def each_with_index
    i = 0
    each do |key, value|
      yield key, value, i
      i += 1
    end
    self
  end

  def keys
    keys = Array(K).new(@length)
    each { |key| keys << key }
    keys
  end

  def values
    values = Array(V).new(@length)
    each { |key, value| values << value }
    values
  end

  def key_index(key)
    each_with_index do |my_key, my_value, i|
      return i if key == my_key
    end
    nil
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
    @first.try &.key
  end

  def first_value
    @first.not_nil!.value
  end

  def first_value?
    @first.try &.value
  end

  def shift
    shift { raise IndexOutOfBounds.new }
  end

  def shift?
    shift { nil }
  end

  def shift
    first = @first
    if first
      delete first.key
      {first.key, first.value}
    else
      yield
    end
  end

  def ==(other : Hash)
    return false unless length == other.length
    each do |key, value|
      entry = other.find_entry(key)
      return false unless entry && entry.value == value
    end
    true
  end

  def dup
    hash = Hash(K, V).new
    each do |key, value|
      hash[key] = value
    end
    hash
  end

  def clone
    hash = Hash(K, V).new
    each do |key, value|
      hash[key] = value.clone
    end
    hash
  end

  def inspect
    to_s
  end

  def to_s
    exec_recursive(:to_s, "{...}") do
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
  end

  # private

  def find_entry(key)
    index = bucket_index key
    entry = @buckets[index]
    find_entry_in_bucket entry, key
  end

  def insert_in_bucket(index, key, value)
    entry = @buckets[index]
    if entry
      while entry
        if @comp.equals?(entry.key, key)
          entry.value = value
          return nil
        end
        if entry.next
          entry = entry.next
        else
          return entry.next = Entry(K, V).new(key, value)
        end
      end
    else
      return @buckets[index] = Entry(K, V).new(key, value)
    end
  end

  def insert_in_bucket_end(index, existing_entry)
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

  def find_entry_in_bucket(entry, key)
    while entry
      if @comp.equals?(entry.key, key)
        return entry
      end
      entry = entry.next
    end
    nil
  end

  def bucket_index(key)
    (@comp.hash(key) % @buckets.length).to_i
  end

  def rehash
    new_size = calculate_new_size(@length)
    @buckets = Array(Entry(K, V)?).new(new_size, nil)
    entry = @first
    while entry
      entry.next = nil
      index = bucket_index entry.key
      insert_in_bucket_end index, entry
      entry = entry.fore
    end
  end

  def calculate_new_size(size)
    new_size = 8
    HASH_PRIMES.each do |hash_size|
      return hash_size if new_size > size
      new_size <<= 1
    end
    raise "Hash table too big"
  end

  class Entry(K, V)
    getter :key
    property :value

    # Next in the linked list of each bucket
    property :next

    # Next in the ordered sense of hash
    property :fore

    # Previous in the ordered sense of hash
    property :back

    def initialize(@key : K, @value : V)
    end

    def to_s
      "(#{key}: #{value})#{self.next ? "*" : ""}"
    end
  end

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
