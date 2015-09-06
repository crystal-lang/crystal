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

  getter size

  def initialize(block = nil : (Hash(K, V), K -> V)?, @comp = StandardComparator, initial_capacity = nil)
    initial_capacity ||= 11
    initial_capacity = 11 if initial_capacity < 11
    initial_capacity = initial_capacity.to_i
    @buckets = Pointer(Entry(K, V)?).malloc(initial_capacity)
    @buckets_size = initial_capacity
    @size = 0
    @block = block
  end

  def self.new(comp = StandardComparator, initial_capacity = nil, &block : (Hash(K, V), K -> V))
    new block, comp
  end

  def self.new(default_value : V, comp = StandardComparator, initial_capacity = nil)
    new(comp, initial_capacity: initial_capacity) { default_value }
  end

  def self.new(comparator)
    new nil, comparator
  end

  # Set the value of *key* to the given *value*.
  #
  # ```
  # h = {} of String => String
  # h["foo"] = "bar"
  # h["foo"] #=> "bar"
  # ```
  def []=(key : K, value : V)
    rehash if @size > 5 * @buckets_size

    index = bucket_index key
    entry = insert_in_bucket index, key, value
    return value unless entry

    @size += 1

    if last = @last
      last.fore = entry
      entry.back = last
    end

    @last = entry
    @first = entry unless @first
    value
  end

  # See `Hash#fetch`
  def [](key)
    fetch(key)
  end

  # Returns the value for the key given by *key*.
  # If not found, returns `nil`. This ignores the default value set by `Hash.new`.
  #
  # ```
  # h = { "foo" => "bar" }
  # h["foo"]? #=> "bar"
  # h["bar"]? #=> nil
  #
  # h = Hash(String, String).new("bar")
  # h["foo"]? #=> nil
  # ```
  def []?(key)
    fetch(key, nil)
  end

  # Returns `true` when key given by *key* exists, otherwise `false`.
  #
  # ```
  # h = { "foo" => "bar" }
  # h.has_key?("foo") #=> true
  # h.has_key?("bar") #=> false
  # ```
  def has_key?(key)
    !!find_entry(key)
  end

  # Returns the value for the key given by *key*.
  # If not found, returns the default value given by `Hash.new`, otherwise raises `KeyError`.
  #
  # ```
  # h = { "foo" => "bar" }
  # h["foo"] #=> "bar"
  #
  # h = Hash(String, String).new("bar")
  # h["foo"] #=> "bar"
  #
  # h = Hash(String, String).new { "bar" }
  # h["foo"] #=> "bar"
  #
  # h = Hash(String, String).new
  # h["foo"] # raises KeyError
  # ```
  def fetch(key)
    fetch(key) do
      if block = @block
        block.call(self, key)
      else
        raise KeyError.new "Missing hash key: #{key.inspect}"
      end
    end
  end

  # Returns the value for the key given by *key*, or when not found the value given by *default*.
  # This ignores the default value set by `Hash.new`.
  #
  # ```
  # h = { "foo" => "bar" }
  # h.fetch("foo", "foo") #=> "bar"
  # h.fetch("bar", "foo") #=> "foo"
  # ```
  def fetch(key, default)
    fetch(key) { default }
  end

  # Returns the value for the key given by *key*, or when not found calls the given block with the key.
  #
  # ```
  # h = { "foo" => "bar" }
  # h.fetch("foo") { |key| key.upcase } #=> "bar"
  # h.fetch("bar") { |key| key.upcase } #=> "BAR"
  # ```
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

  # Deletes the key-value pair and returns the value.
  #
  # ```
  # h = { "foo" => "bar" }
  # h.delete("foo")     #=> "bar"
  # h.fetch("foo", nil) #=> nil
  # ```
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
        @size -= 1
        return entry.value
      end
      previous_entry = entry
      entry = entry.next
    end
    nil
  end

  # Deletes each key-value pair for which the given block returns `true`.
  #
  # ```
  # h = { "foo" => "bar", "fob" => "baz", "bar" => "qux" }
  # h.delete_if { |key, value| key.starts_with?("fo") }
  # h #=> { "bar" => "qux" }
  # ```
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

  # Returns `true` when hash contains no key-value pairs.
  #
  # ```
  # h = Hash(String, String).new
  # h.empty? #=> true
  #
  # h = { "foo" => "bar" }
  # h.empty? #=> false
  # ```
  def empty?
    @size == 0
  end

  # Calls the given block for each key-value pair and passes in the key and the value.
  #
  # ```
  # h = { "foo" => "bar" }
  # h.each do |key, value|
  #   key   #=> "foo"
  #   value #=> "bar"
  # end
  # ```
  def each
    current = @first
    while current
      yield current.key, current.value
      current = current.fore
    end
    self
  end

  # Returns an iterator over the hash entries.
  # Which behaves like an `Iterator` returning a `Tuple` consisting of the key and value types.
  #
  # ```
  # hsh = { "foo" => "bar", "baz" => "qux" }
  # iterator = hsh.each
  #
  # entry = iterator.next
  # entry[0] #=> "foo"
  # entry[1] #=> "bar"
  #
  # entry = iterator.next
  # entry[0] #=> "baz"
  # entry[1] #=> "qux"
  # ```
  def each
    EntryIterator(K, V).new(self, @first)
  end

  # Calls the given block for each key-value pair and passes in the key.
  #
  # ```
  # h = { "foo" => "bar" }
  # h.each_key do |key|
  #   key #=> "foo"
  # end
  # ```
  def each_key
    each do |key, value|
      yield key
    end
  end

  # Returns an iterator over the hash keys.
  # Which behaves like an `Iterator` consisting of the key's types.
  #
  # ```
  # hsh = { "foo" => "bar", "baz" => "qux" }
  # iterator = hsh.each_key
  #
  # key = iterator.next
  # key #=> "foo"
  #
  # key = iterator.next
  # key #=> "baz"
  # ```
  def each_key
    KeyIterator(K, V).new(self, @first)
  end

  # Calls the given block for each key-value pair and passes in the value.
  #
  # ```
  # h = { "foo" => "bar" }
  # h.each_value do |key|
  #   key #=> "bar"
  # end
  # ```
  def each_value
    each do |key, value|
      yield value
    end
  end

  # Returns an iterator over the hash values.
  # Which behaves like an `Iterator` consisting of the value's types.
  #
  # ```
  # hsh = { "foo" => "bar", "baz" => "qux" }
  # iterator = hsh.each_value
  #
  # value = iterator.next
  # value #=> "bar"
  #
  # value = iterator.next
  # value #=> "qux"
  # ```
  def each_value
    ValueIterator(K, V).new(self, @first)
  end

  # Calls the given block for each key-value pair and passes in the key, value, and index.
  #
  # ```
  # h = { "foo" => "bar" }
  # 
  # h.each_with_index do |key, value, index|
  #   key   #=> "foo"
  #   value #=> "bar"
  #   index #=> 0
  # end
  # 
  # h.each_with_index(3) do |key, value, index|
  #   key   #=> "foo"
  #   value #=> "bar"
  #   index #=> 3
  # end
  # ```
  def each_with_index(offset = 0)
    i = offset
    each do |key, value|
      yield key, value, i
      i += 1
    end
    self
  end

  # Iterates the given block for each element with an arbitrary object given, and returns the initially given object.
  # ```
  # evens = (1..10).each_with_object([] of Int32) { |i, a| a << i*2 }
  # #=> [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
  # ```
  def each_with_object(memo)
    each do |k, v|
      yield(memo, k, v)
    end
    memo
  end

  # Returns a new `Array` with all the keys.
  #
  # ```
  # h = { "foo" => "bar", "baz" => "bar" }
  # h.keys #=> ["foo", "baz"]
  # ```
  def keys
    keys = Array(K).new(@size)
    each { |key| keys << key }
    keys
  end

  def values
    values = Array(V).new(@size)
    each { |key, value| values << value }
    values
  end

  # Returns a new `Array` of tuples populated with each key-value pair.
  #
  # ```
  # h = { "foo" => "bar", "baz" => "qux" }
  # h.to_a #=> [{"foo", "bar"}, {"baz", "qux}]
  # ```
  def to_a
    ary = Array({K, V}).new(@size)
    each do |key, value|
      ary << {key, value}
    end
    ary
  end

  # Returns the index of the given key, or `nil` when not found.
  # The keys are ordered based on when they were inserted.
  #
  # ```
  # h = { "foo" => "bar", "baz" => "qux" }
  # h.key_index("foo") #=> 0
  # h.key_index("qux") #=> nil
  # ```
  def key_index(key)
    each_with_index do |my_key, my_value, i|
      return i if key == my_key
    end
    nil
  end

  def map(&block : K, V -> U)
    array = Array(U).new(@size)
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

  # Returns a new hash consisting of entries for which the block returns true.
  # ```
  # h = { "a" => 100, "b" => 200, "c" => 300 }
  # h.select {|k,v| k > "a"}  #=> {"b" => 200, "c" => 300}
  # h.select {|k,v| v < 200}  #=> {"a" => 100}
  # ```
  def select(&block : K, V -> U)
    reject{ |k, v| !yield(k, v) }
  end

  # Equivalent to `Hash#select` but makes modification on the current object rather that returning a new one. Returns nil if no changes were made
  def select!(&block : K, V -> U)
    reject!{ |k, v| !yield(k, v) }
  end

  # Returns a new hash consisting of entries for which the block returns false.
  # ```
  # h = { "a" => 100, "b" => 200, "c" => 300 }
  # h.reject {|k,v| k > "a"}  #=> {"a" => 100}
  # h.reject {|k,v| v < 200}  #=> {"b" => 200, "c" => 300}
  # ``` 
  def reject(&block : K, V -> U)
    each_with_object({} of K => V) do |memo, k, v|
      memo[k] = v unless yield k, v
    end
  end

  # Equivalent to `Hash#reject`, but makes modification on the current object rather that returning a new one. Returns nil if no changes were made.
  def reject!(&block : K, V -> U)
    num_entries = size
    each do |key, value|
      delete(key) if yield(key, value)
    end
    num_entries == size ? nil : self
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

  def clear
    @buckets_size.times do |i|
      @buckets[i] = nil
    end
    @size = 0
    @first = nil
    @last = nil
    self
  end

  def ==(other : Hash)
    return false unless size == other.size
    each do |key, value|
      entry = other.find_entry(key)
      return false unless entry && entry.value == value
    end
    true
  end

  def hash
    hash = size
    each do |key, value|
      hash = 31 * hash + key.hash
      hash = 31 * hash + value.hash
    end
    hash
  end

  def dup
    hash = Hash(K, V).new(initial_capacity: @buckets_size)
    each do |key, value|
      hash[key] = value
    end
    hash
  end

  def clone
    hash = Hash(K, V).new(initial_capacity: @buckets_size)
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
    new_size = calculate_new_size(@size)
    @buckets = @buckets.realloc(new_size)
    new_size.times { |i| @buckets[i] = nil }
    @buckets_size = new_size
    entry = @first
    while entry
      entry.next = nil
      index = bucket_index entry.key
      insert_in_bucket_end index, entry
      entry = entry.fore
    end
  end

  def invert
    hash = Hash(V, K).new(initial_capacity: @buckets_size)
    self.each do |k, v|
      hash[v] = k
    end
    hash
  end

  def all?
    each do |k, v|
      return false unless yield(k, v)
    end
    true
  end

  def any?
    each do |k, v|
      return true if yield(k, v)
    end
    false
  end

  def any?
    !empty?
  end

  def inject(memo)
    each do |k, v|
      memo = yield(memo, k, v)
    end
    memo
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
    (@comp.hash(key).abs % @buckets_size).to_i
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
