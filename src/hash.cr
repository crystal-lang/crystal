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

  getter length

  def initialize(block = nil : (Hash(K, V), K -> V)?, @comp = StandardComparator)
    @buckets = Pointer(Entry(K, V)?).malloc(11)
    @buckets_length = 11
    @length = 0
    @block = block
  end

  def self.new(comp = StandardComparator, &block : (Hash(K, V), K -> V))
    new block, comp
  end

  def self.new(default_value : V, comp = StandardComparator)
    new(comp) { default_value }
  end

  def self.new(comparator)
    new nil, comparator
  end

  def []=(key : K, value : V)
    rehash if @length > 5 * @buckets_length

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
        raise KeyError.new "Missing hash value: #{key.inspect}"
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

  # Returns a tuple populated with the elements at the given indexes.
  # Raises if any index is invalid.
  #
  # ```
  # {"a": 1, "b": 2, "c": 3, "d": 4}.values_at("a", "c") #=> {1, 3}
  # ```
  def values_at(*indexes : K)
    indexes.map {|index| self[index] }
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
        return entry.value
      end
      previous_entry = entry
      entry = entry.next
    end
    nil
  end

  def delete_if
    keys_to_delete = [] of K
    each do |key, value|
      keys_to_delete << key if yield(key, value)
    end
    keys_to_delete.each do |key|
      delete(key)
    end
    self
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

  def each
    EntryIterator(K, V).new(self, @first)
  end

  def each_key
    each do |key, value|
      yield key
    end
  end

  def each_key
    KeyIterator(K, V).new(self, @first)
  end

  def each_value
    each do |key, value|
      yield value
    end
  end

  def each_value
    ValueIterator(K, V).new(self, @first)
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

  def to_a
    ary = Array({K, V}).new(@length)
    each do |key, value|
      ary << {key, value}
    end
    ary
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

  def merge(other : Hash(L, W))
    hash = Hash(K | L, V | W).new
    hash.merge! self
    hash.merge! other
    hash
  end

  def merge(other : Hash(L, W), &block : K, V, W -> V | W)
    hash = Hash(K | L, V | W).new
    hash.merge! self
    hash.merge!(other) { |k, v1, v2| yield k, v1, v2 }
    hash
  end

  def merge!(other : Hash(K, V))
    other.each do |k, v|
      self[k] = v
    end
    self
  end

  def merge!(other : Hash(K, V), &block : K, V, V -> V)
    other.each do |k, v|
      if self.has_key?(k)
        self[k] = yield k, self[k], v
      else
        self[k] = v
      end
    end
    self
  end

  def self.zip(ary1 : Array(K), ary2 : Array(V))
    hash = {} of K => V
    ary1.each_with_index do |key, i|
      hash[key] = ary2[i]
    end
    hash
  end

  def first
    first = @first.not_nil!
    {first.key, first.value}
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
    shift { raise IndexError.new }
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

  def ==(other : Hash)
    return false unless length == other.length
    each do |key, value|
      entry = other.find_entry(key)
      return false unless entry && entry.value == value
    end
    true
  end

  def hash
    hash = length
    each do |key, value|
      hash = 31 * hash + key.hash
      hash = 31 * hash + value.hash
    end
    hash
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

  def inspect(io : IO)
    to_s(io)
  end

  def to_s(io : IO)
    executed = exec_recursive(:to_s) do
      io << "{"
      found_one = false
      each do |key, value|
        io << ", " if found_one
        key.inspect(io)
        io << " => "
        value.inspect(io)
        found_one = true
      end
      io << "}"
    end
    io << "{...}" unless executed
  end

  def to_h
    self
  end

  def rehash
    new_size = calculate_new_size(@length)
    @buckets = @buckets.realloc(new_size)
    new_size.times { |i| @buckets[i] = nil }
    @buckets_length = new_size
    entry = @first
    while entry
      entry.next = nil
      index = bucket_index entry.key
      insert_in_bucket_end index, entry
      entry = entry.fore
    end
  end

  def invert
    hash = Hash(V, K).new
    self.each do |k, v|
      hash[v] = k
    end
    hash
  end

  protected def find_entry(key)
    index = bucket_index key
    entry = @buckets[index]
    find_entry_in_bucket entry, key
  end

  private def insert_in_bucket(index, key, value)
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

  private def find_entry_in_bucket(entry, key)
    while entry
      if @comp.equals?(entry.key, key)
        return entry
      end
      entry = entry.next
    end
    nil
  end

  private def bucket_index(key)
    (@comp.hash(key).abs % @buckets_length).to_i
  end

  private def calculate_new_size(size)
    new_size = 8
    HASH_PRIMES.each do |hash_size|
      return hash_size if new_size > size
      new_size <<= 1
    end
    raise "Hash table too big"
  end

  # :nodoc:
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
  end

  # :nodoc:
  module BaseIterator
    def initialize(@hash, @current)
    end

    def base_next
      if current = @current
        value = yield current
        @current = current.fore
        value
      else
        stop
      end
    end

    def rewind
      @current = @hash.@first
    end
  end

  # :nodoc:
  class EntryIterator(K, V)
    include BaseIterator
    include Iterator({K, V})

    def next
      base_next { |entry| {entry.key, entry.value} }
    end
  end

  # :nodoc:
  class KeyIterator(K, V)
    include BaseIterator
    include Iterator(K)

    def next
      base_next &.key
    end
  end

  # :nodoc:
  class ValueIterator(K, V)
    include BaseIterator
    include Iterator(V)

    def next
      base_next &.value
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
