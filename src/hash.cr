require "crystal/hasher"

# A `Hash` represents a mapping of keys to values.
#
# See the [official docs](http://crystal-lang.org/docs/syntax_and_semantics/literals/hash.html) for the basics.
class Hash(K, V)
  include Enumerable({K, V})
  include Iterable({K, V})

  getter size : Int32
  @buckets_size : Int32
  @first : Entry(K, V)?
  @last : Entry(K, V)?
  @block : (self, K -> V)?

  def initialize(block : (Hash(K, V), K -> V)? = nil, initial_capacity = nil)
    initial_capacity ||= 11
    initial_capacity = 11 if initial_capacity < 11
    initial_capacity = initial_capacity.to_i
    @buckets = Pointer(Entry(K, V)?).malloc(initial_capacity)
    @buckets_size = initial_capacity
    @size = 0
    @block = block
  end

  def self.new(initial_capacity = nil, &block : (Hash(K, V), K -> V))
    new block, initial_capacity: initial_capacity
  end

  def self.new(default_value : V, initial_capacity = nil)
    new(initial_capacity: initial_capacity) { default_value }
  end

  # Sets the value of *key* to the given *value*.
  #
  # ```
  # h = {} of String => String
  # h["foo"] = "bar"
  # h["foo"] # => "bar"
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

  # See also: `Hash#fetch`.
  def [](key)
    fetch(key)
  end

  # Returns the value for the key given by *key*.
  # If not found, returns `nil`. This ignores the default value set by `Hash.new`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h["foo"]? # => "bar"
  # h["bar"]? # => nil
  #
  # h = Hash(String, String).new("bar")
  # h["foo"]? # => nil
  # ```
  def []?(key)
    fetch(key, nil)
  end

  # Returns `true` when key given by *key* exists, otherwise `false`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.has_key?("foo") # => true
  # h.has_key?("bar") # => false
  # ```
  def has_key?(key)
    !!find_entry(key)
  end

  # Returns `true` when value given by *value* exists, otherwise `false`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.has_value?("foo") # => false
  # h.has_value?("bar") # => true
  # ```
  def has_value?(val)
    each_value do |value|
      return true if value == val
    end
    false
  end

  # Returns the value for the key given by *key*.
  # If not found, returns the default value given by `Hash.new`, otherwise raises `KeyError`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h["foo"] # => "bar"
  #
  # h = Hash(String, String).new("bar")
  # h["foo"] # => "bar"
  #
  # h = Hash(String, String).new { "bar" }
  # h["foo"] # => "bar"
  #
  # h = Hash(String, String).new
  # h["foo"] # raises KeyError
  # ```
  def fetch(key)
    fetch(key) do
      if (block = @block) && key.is_a?(K)
        block.call(self, key.as(K))
      else
        raise KeyError.new "Missing hash key: #{key.inspect}"
      end
    end
  end

  # Returns the value for the key given by *key*, or when not found the value given by *default*.
  # This ignores the default value set by `Hash.new`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.fetch("foo", "foo") # => "bar"
  # h.fetch("bar", "foo") # => "foo"
  # ```
  def fetch(key, default)
    fetch(key) { default }
  end

  # Returns the value for the key given by *key*, or when not found calls the given block with the key.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.fetch("foo") { |key| key.upcase } # => "bar"
  # h.fetch("bar") { |key| key.upcase } # => "BAR"
  # ```
  def fetch(key)
    entry = find_entry(key)
    entry ? entry.value : yield key
  end

  # Returns a tuple populated with the elements at the given *indexes*.
  # Raises if any index is invalid.
  #
  # ```
  # {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.values_at("a", "c") # => {1, 3}
  # ```
  def values_at(*indexes : K)
    indexes.map { |index| self[index] }
  end

  # Returns the first key with the given *value*, else raises `KeyError`.
  #
  # ```
  # hash = {"foo" => "bar", "baz" => "qux"}
  # hash.key("bar")    # => "foo"
  # hash.key("qux")    # => "baz"
  # hash.key("foobar") # raises KeyError (Missing hash key for value: foobar)
  # ```
  def key(value)
    key(value) { raise KeyError.new "Missing hash key for value: #{value}" }
  end

  # Returns the first key with the given *value*, else `nil`.
  #
  # ```
  # hash = {"foo" => "bar", "baz" => "qux"}
  # hash.key?("bar")    # => "foo"
  # hash.key?("qux")    # => "baz"
  # hash.key?("foobar") # => nil
  # ```
  def key?(value)
    key(value) { nil }
  end

  # Returns the first key with the given *value*, else yields *value* with the given block.
  #
  # ```
  # hash = {"foo" => "bar"}
  # hash.key("bar") { |value| value.upcase } # => "foo"
  # hash.key("qux") { |value| value.upcase } # => "QUX"
  # ```
  def key(value)
    each do |k, v|
      return k if v == value
    end
    yield value
  end

  # Deletes the key-value pair and returns the value, otherwise returns `nil`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.delete("foo")     # => "bar"
  # h.fetch("foo", nil) # => nil
  # ```
  def delete(key)
    delete(key) { nil }
  end

  # Deletes the key-value pair and returns the value, else yields *key* with given block.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.delete("foo") { |key| "#{key} not found" } # => "bar"
  # h.fetch("foo", nil)                          # => nil
  # h.delete("baz") { |key| "#{key} not found" } # => "baz not found"
  # ```
  def delete(key)
    index = bucket_index(key)
    entry = @buckets[index]

    previous_entry = nil
    while entry
      if entry.key == key
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
    yield key
  end

  # Deletes each key-value pair for which the given block returns `true`.
  #
  # ```
  # h = {"foo" => "bar", "fob" => "baz", "bar" => "qux"}
  # h.delete_if { |key, value| key.starts_with?("fo") }
  # h # => { "bar" => "qux" }
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
  # h.empty? # => true
  #
  # h = {"foo" => "bar"}
  # h.empty? # => false
  # ```
  def empty?
    @size == 0
  end

  # Calls the given block for each key-value pair and passes in the key and the value.
  #
  # ```
  # h = {"foo" => "bar"}
  #
  # h.each do |key, value|
  #   key   # => "foo"
  #   value # => "bar"
  # end
  #
  # h.each do |key_and_value|
  #   key_and_value # => {"foo", "bar"}
  # end
  # ```
  def each : Nil
    current = @first
    while current
      yield({current.key, current.value})
      current = current.fore
    end
  end

  # Returns an iterator over the hash entries.
  # Which behaves like an `Iterator` returning a `Tuple` consisting of the key and value types.
  #
  # ```
  # hsh = {"foo" => "bar", "baz" => "qux"}
  # iterator = hsh.each
  #
  # iterator.next # => {"foo", "bar"}
  # iterator.next # => {"baz", "qux"}
  # ```
  def each
    EntryIterator(K, V).new(self, @first)
  end

  # Calls the given block for each key-value pair and passes in the key.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.each_key do |key|
  #   key # => "foo"
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
  # hsh = {"foo" => "bar", "baz" => "qux"}
  # iterator = hsh.each_key
  #
  # key = iterator.next
  # key # => "foo"
  #
  # key = iterator.next
  # key # => "baz"
  # ```
  def each_key
    KeyIterator(K, V).new(self, @first)
  end

  # Calls the given block for each key-value pair and passes in the value.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.each_value do |value|
  #   value # => "bar"
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
  # hsh = {"foo" => "bar", "baz" => "qux"}
  # iterator = hsh.each_value
  #
  # value = iterator.next
  # value # => "bar"
  #
  # value = iterator.next
  # value # => "qux"
  # ```
  def each_value
    ValueIterator(K, V).new(self, @first)
  end

  # Returns a new `Array` with all the keys.
  #
  # ```
  # h = {"foo" => "bar", "baz" => "bar"}
  # h.keys # => ["foo", "baz"]
  # ```
  def keys
    keys = Array(K).new(@size)
    each_key { |key| keys << key }
    keys
  end

  # Returns only the values as an `Array`.
  #
  # ```
  # h = {"foo" => "bar", "baz" => "qux"}
  # h.values # => ["bar", "qux"]
  # ```
  def values
    values = Array(V).new(@size)
    each_value { |value| values << value }
    values
  end

  # Returns the index of the given key, or `nil` when not found.
  # The keys are ordered based on when they were inserted.
  #
  # ```
  # h = {"foo" => "bar", "baz" => "qux"}
  # h.key_index("foo") # => 0
  # h.key_index("qux") # => nil
  # ```
  def key_index(key)
    each_with_index do |(my_key, my_value), index|
      return index if key == my_key
    end
    nil
  end

  # Returns a new `Hash` with the keys and values of this hash and *other* combined.
  # A value in *other* takes precedence over the one in this hash.
  #
  # ```
  # hash = {"foo" => "bar"}
  # hash.merge({"baz" => "qux"})
  # # => {"foo" => "bar", "baz" => "qux"}
  # hash
  # # => {"foo" => "bar"}
  # ```
  def merge(other : Hash(L, W)) forall L, W
    hash = Hash(K | L, V | W).new
    hash.merge! self
    hash.merge! other
    hash
  end

  def merge(other : Hash(L, W), &block : K, V, W -> V | W) forall L, W
    hash = Hash(K | L, V | W).new
    hash.merge! self
    hash.merge!(other) { |k, v1, v2| yield k, v1, v2 }
    hash
  end

  # Similar to `#merge`, but the receiver is modified.
  #
  # ```
  # hash = {"foo" => "bar"}
  # hash.merge!({"baz" => "qux"})
  # hash # => {"foo" => "bar", "baz" => "qux"}
  # ```
  def merge!(other : Hash)
    other.each do |k, v|
      self[k] = v
    end
    self
  end

  def merge!(other : Hash, &block)
    other.each do |k, v|
      if self.has_key?(k)
        self[k] = yield k, self[k], v
      else
        self[k] = v
      end
    end
    self
  end

  # Returns a new hash consisting of entries for which the block returns `true`.
  # ```
  # h = {"a" => 100, "b" => 200, "c" => 300}
  # h.select { |k, v| k > "a" } # => {"b" => 200, "c" => 300}
  # h.select { |k, v| v < 200 } # => {"a" => 100}
  # ```
  def select(&block : K, V -> _)
    reject { |k, v| !yield(k, v) }
  end

  # Equivalent to `Hash#select` but makes modification on the current object rather that returning a new one. Returns `nil` if no changes were made
  def select!(&block : K, V -> _)
    reject! { |k, v| !yield(k, v) }
  end

  # Returns a new hash consisting of entries for which the block returns `false`.
  # ```
  # h = {"a" => 100, "b" => 200, "c" => 300}
  # h.reject { |k, v| k > "a" } # => {"a" => 100}
  # h.reject { |k, v| v < 200 } # => {"b" => 200, "c" => 300}
  # ```
  def reject(&block : K, V -> _)
    each_with_object({} of K => V) do |(k, v), memo|
      memo[k] = v unless yield k, v
    end
  end

  # Equivalent to `Hash#reject`, but makes modification on the current object rather that returning a new one. Returns `nil` if no changes were made.
  def reject!(&block : K, V -> _)
    num_entries = size
    each do |key, value|
      delete(key) if yield(key, value)
    end
    num_entries == size ? nil : self
  end

  # Returns a new `Hash` without the given keys.
  #
  # ```
  # {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.reject("a", "c") # => {"b" => 2, "d" => 4}
  # ```
  def reject(*keys)
    hash = self.dup
    hash.reject!(*keys)
  end

  # Removes a list of keys out of hash.
  #
  # ```
  # h = {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.reject!("a", "c")
  # h # => {"b" => 2, "d" => 4}
  # ```
  def reject!(keys : Array | Tuple)
    keys.each { |k| delete(k) }
    self
  end

  def reject!(*keys)
    reject!(keys)
  end

  # Returns a new `Hash` with the given keys.
  #
  # ```
  # {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.select("a", "c") # => {"a" => 1, "c" => 3}
  # ```
  def select(keys : Array | Tuple)
    hash = {} of K => V
    keys.each { |k| hash[k] = self[k] if has_key?(k) }
    hash
  end

  def select(*keys)
    self.select(keys)
  end

  # Removes every element except the given ones.
  #
  # ```
  # h = {"a" => 1, "b" => 2, "c" => 3, "d" => 4}.select!("a", "c")
  # h # => {"a" => 1, "c" => 3}
  # ```
  def select!(keys : Array | Tuple)
    each { |k, v| delete(k) unless keys.includes?(k) }
    self
  end

  def select!(*keys)
    select!(keys)
  end

  # Returns new `Hash` without `nil` values.
  #
  # ```
  # hash = {"hello" => "world", "foo" => nil}
  # hash.compact # => {"hello" => "world"}
  # ```
  def compact
    each_with_object({} of K => typeof(self.first_value.not_nil!)) do |(key, value), memo|
      memo[key] = value unless value.nil?
    end
  end

  # Removes all `nil` value from `self`. Returns `nil` if no changes were made.
  #
  # ```
  # hash = {"hello" => "world", "foo" => nil}
  # hash.compact! # => {"hello" => "world"}
  # hash.compact! # => nil
  # ```
  def compact!
    reject! { |key, value| value.nil? }
  end

  # Zips two arrays into a `Hash`, taking keys from *ary1* and values from *ary2*.
  #
  # ```
  # Hash.zip(["key1", "key2", "key3"], ["value1", "value2", "value3"])
  # # => {"key1" => "value1", "key2" => "value2", "key3" => "value3"}
  # ```
  def self.zip(ary1 : Array(K), ary2 : Array(V))
    hash = {} of K => V
    ary1.each_with_index do |key, i|
      hash[key] = ary2[i]
    end
    hash
  end

  # Returns the first key in the hash.
  def first_key
    @first.not_nil!.key
  end

  # Returns the first key if it exists, or returns `nil`.
  #
  # ```
  # hash = {"foo" => "bar"}
  # hash.first_key? # => "foo"
  # hash.clear
  # hash.first_key? # => nil
  # ```
  def first_key?
    @first.try &.key
  end

  # Returns the first value in the hash.
  def first_value
    @first.not_nil!.value
  end

  # Similar to `#first_key?`, but returns its value.
  def first_value?
    @first.try &.value
  end

  # Deletes and returns the first key-value pair in the hash,
  # or raises `IndexError` if the hash is empty.
  #
  # ```
  # hash = {"foo" => "bar", "baz" => "qux"}
  # hash.shift # => {"foo", "bar"}
  # hash       # => {"baz" => "qux"}
  #
  # hash = {} of String => String
  # hash.shift # raises IndexError
  # ```
  def shift
    shift { raise IndexError.new }
  end

  # Same as `#shift`, but returns `nil` if the hash is empty.
  #
  # ```
  # hash = {"foo" => "bar", "baz" => "qux"}
  # hash.shift? # => {"foo", "bar"}
  # hash        # => {"baz" => "qux"}
  #
  # hash = {} of String => String
  # hash.shift? # => nil
  # ```
  def shift?
    shift { nil }
  end

  # Deletes and returns the first key-value pair in the hash.
  # Yields to the given block if the hash is empty.
  #
  # ```
  # hash = {"foo" => "bar", "baz" => "qux"}
  # hash.shift { true } # => {"foo", "bar"}
  # hash                # => {"baz" => "qux"}
  #
  # hash = {} of String => String
  # hash.shift { true } # => true
  # hash                # => {}
  # ```
  def shift
    first = @first
    if first
      delete first.key
      {first.key, first.value}
    else
      yield
    end
  end

  # Empties a `Hash` and returns it.
  #
  # ```
  # hash = {"foo" => "bar"}
  # hash.clear # => {}
  # ```
  def clear
    @buckets_size.times do |i|
      @buckets[i] = nil
    end
    @size = 0
    @first = nil
    @last = nil
    self
  end

  # Compares with *other*. Returns `true` if all key-value pairs are the same.
  def ==(other : Hash)
    return false unless size == other.size
    each do |key, value|
      entry = other.find_entry(key)
      return false unless entry && entry.value == value
    end
    true
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    # The hash value must be the same regardless of the
    # order of the keys.
    result = hasher.result

    each do |key, value|
      copy = hasher
      copy = key.hash(copy)
      copy = value.hash(copy)
      result += copy.result
    end

    result.hash(hasher)
  end

  # Duplicates a `Hash`.
  #
  # ```
  # hash_a = {"foo" => "bar"}
  # hash_b = hash_a.dup
  # hash_b.merge!({"baz" => "qux"})
  # hash_a # => {"foo" => "bar"}
  # ```
  def dup
    hash = Hash(K, V).new(initial_capacity: @buckets_size)
    each do |key, value|
      hash[key] = value
    end
    hash
  end

  # Similar to `#dup`, but duplicates the values as well.
  #
  # ```
  # hash_a = {"foobar" => {"foo" => "bar"}}
  # hash_b = hash_a.clone
  # hash_b["foobar"]["foo"] = "baz"
  # hash_a # => {"foobar" => {"foo" => "bar"}}
  # ```
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

  # Converts to a `String`.
  #
  # ```
  # h = {"foo" => "bar"}
  # h.to_s       # => "{\"foo\" => \"bar\"}"
  # h.to_s.class # => String
  # ```
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

  def pretty_print(pp) : Nil
    executed = exec_recursive(:pretty_print) do
      pp.list("{", self, "}") do |key, value|
        pp.group do
          key.pretty_print(pp)
          pp.text " =>"
          pp.nest do
            pp.breakable
            value.pretty_print(pp)
          end
        end
      end
    end
    pp.text "{...}" unless executed
  end

  # Returns `self`.
  def to_h
    self
  end

  def rehash
    new_size = calculate_new_size(@size)
    @buckets = @buckets.realloc(new_size)
    new_size.times { |i| @buckets[i] = nil }
    @buckets_size = new_size
    entry = @last
    while entry
      index = bucket_index entry.key
      entry.next = @buckets[index]
      @buckets[index] = entry
      entry = entry.back
    end
  end

  # Inverts keys and values. If there are duplicated values, the last key becomes the new value.
  #
  # ```
  # {"foo" => "bar"}.invert                 # => {"bar" => "foo"}
  # {"foo" => "bar", "baz" => "bar"}.invert # => {"bar" => "baz"}
  # ```
  def invert
    hash = Hash(V, K).new(initial_capacity: @buckets_size)
    self.each do |k, v|
      hash[v] = k
    end
    hash
  end

  protected def find_entry(key)
    return nil if empty?

    index = bucket_index key
    entry = @buckets[index]
    find_entry_in_bucket entry, key
  end

  private def insert_in_bucket(index, key, value)
    entry = @buckets[index]
    if entry
      while entry
        if entry.key == key
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

  private def find_entry_in_bucket(entry, key)
    while entry
      if entry.key == key
        return entry
      end
      entry = entry.next
    end
    nil
  end

  private def bucket_index(key)
    key.hash.remainder(@buckets_size).to_i
  end

  private def calculate_new_size(size)
    new_size = 8
    HASH_PRIMES.each do |hash_size|
      return hash_size if new_size > size
      new_size <<= 1
    end
    raise "Hash table too big"
  end

  private class Entry(K, V)
    getter key : K
    property value : V

    # Next in the linked list of each bucket
    property next : self?

    # Next in the ordered sense of hash
    property fore : self?

    # Previous in the ordered sense of hash
    property back : self?

    def initialize(@key : K, @value : V)
    end
  end

  private module BaseIterator
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

  private class EntryIterator(K, V)
    include BaseIterator
    include Iterator({K, V})

    @hash : Hash(K, V)
    @current : Entry(K, V)?

    def next
      base_next { |entry| {entry.key, entry.value} }
    end
  end

  private class KeyIterator(K, V)
    include BaseIterator
    include Iterator(K)

    @hash : Hash(K, V)
    @current : Entry(K, V)?

    def next
      base_next &.key
    end
  end

  private class ValueIterator(K, V)
    include BaseIterator
    include Iterator(V)

    @hash : Hash(K, V)
    @current : Entry(K, V)?

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
    0,
  ]
end
