require "crystal/hasher"

# A `Hash` represents a mapping of keys to values.
#
# See the [official docs](http://crystal-lang.org/docs/syntax_and_semantics/literals/hash.html) for the basics.
class Hash(K, V)
  include Enumerable({K, V})
  include Iterable({K, V})

  getter size : Int32
  @format : UInt8
  @rebuild_num : UInt16
  @first : UInt32
  @last : UInt32
  @index : Pointer(UInt32)
  @hashes : Pointer(UInt64)
  @entries : Pointer(Entry(K, V))
  @block : (self, K -> V)?

  def initialize(block : (Hash(K, V), K -> V)? = nil, initial_capacity = nil)
    @size = 0
    @format = 0_u8
    @rebuild_num = 0_u16
    @first = 0_u32
    @last = 0_u32
    @index = Pointer(UInt32).new(0)
    @hashes = Pointer(UInt64).new(0)
    @entries = Pointer(Entry(K, V)).new(0)
    @block = block
    unless initial_capacity.nil?
      resize_data(calculate_new_size(initial_capacity))
    end
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
  def []=(key, value)
    hash = hash_key(key)
    entry, _ = find_entry(hash, key)
    if entry.null?
      idx = push_entry(hash, key, value)
      insert_index_reuse(idx)
    else
      entry.value.value = value
    end
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
    hash = hash_key(key)
    entry, _ = find_entry(hash, key)
    !entry.null?
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
    hash = hash_key(key)
    entry, _ = find_entry(hash, key)
    entry ? entry.value.value : yield key
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
    hash = hash_key(key)
    entry, idx = find_entry(hash, key)
    unless entry.null?
      value = entry.value.value
      delete_idx(idx)
      value
    else
      yield key
    end
  end

  # Deletes each key-value pair for which the given block returns `true`.
  #
  # ```
  # h = {"foo" => "bar", "fob" => "baz", "bar" => "qux"}
  # h.delete_if { |key, value| key.starts_with?("fo") }
  # h # => { "bar" => "qux" }
  # ```
  def delete_if
    each_entry do |entry, idx|
      if yield(entry.value.pair)
        delete_idx(idx)
      end
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
    each_entry do |entry, _|
      yield(entry.value.pair)
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
    EntryIterator(K, V).new(self, @first, @rebuild_num)
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
    KeyIterator(K, V).new(self, @first, @rebuild_num)
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
    ValueIterator(K, V).new(self, @first, @rebuild_num)
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
    hash = hash_key(key)
    entry, idx = find_entry(hash, key)
    if entry.null?
      nil
    elsif @last - @first == @size
      (idx - @first).to_i
    else
      index = 0
      @first.upto(idx) do |i|
        index += 1 if @hashes[i] != 0_u64
      end
      index
    end
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
  def reject!
    num_entries = size
    delete_if { |k, v| yield k, v }
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
    nil.not_nil! if empty?
    @entries[@first].key
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
    unless empty?
      @entries[@first].key
    else
      nil
    end
  end

  # Returns the first value in the hash.
  def first_value
    nil.not_nil! if empty?
    @entries[@first].value
  end

  # Similar to `#first_key?`, but returns its value.
  def first_value?
    unless empty?
      @entries[@first].value
    else
      nil
    end
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
    unless empty?
      idx = @first
      res = @entries[idx].pair
      delete_idx(idx)
      res
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
    resize_data(0_u8)
    @rebuild_num += 1_u16
    @size = 0
    @first = 0_u32
    @last = 0_u32
    self
  end

  # Compares with *other*. Returns `true` if all key-value pairs are the same.
  def ==(other : Hash)
    return false unless size == other.size
    each_entry do |entry, idx|
      other_entry, _ = other.find_entry(@hashes[idx], entry.value.key)
      return false unless other_entry
      return false unless other_entry.value.value == entry.value.value
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
    copy = super
    copy.init_dup(self)
  end

  protected def init_dup(original)
    index = nindex(@format)
    entries = nentries(@format)
    @index = Pointer(UInt32).malloc(index)
    @hashes = Pointer(UInt64).malloc(entries)
    @entries = Pointer(Entry(K, V)).malloc(entries)
    @index.copy_from(original.@index, index)
    @hashes.copy_from(original.@hashes, entries)
    @entries.copy_from(original.@entries, entries)
    self
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
    copy = dup
    copy.init_clone
  end

  protected def init_clone
    each_entry do |entry, _|
      entry.value.key = entry.value.key.clone
      entry.value.value = entry.value.value.clone
    end
    self
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

  # Inverts keys and values. If there are duplicated values, the last key becomes the new value.
  #
  # ```
  # {"foo" => "bar"}.invert                 # => {"bar" => "foo"}
  # {"foo" => "bar", "baz" => "bar"}.invert # => {"bar" => "baz"}
  # ```
  def invert
    hash = Hash(V, K).new(initial_capacity: @size)
    self.each do |k, v|
      hash[v] = k
    end
    hash
  end

  @[AlwaysInline]
  private def each_entry
    return if empty?
    rnum = @rebuild_num
    @first.upto(@last - 1) do |idx|
      if @hashes[idx] != 0_u64
        yield (@entries + idx), idx
        raise "Hash modified during iteration" unless rnum == @rebuild_num
      end
    end
  end

  @[AlwaysInline]
  protected def iter_index(hash : UInt64)
    mask = indexmask(@format)
    pos = hash & mask
    mix = hash
    d = 1_u64
    while true
      yield pos.to_u32
      pos = (pos + d) & mask
      mix >>= 8
      d += (1_u64 + mix) & mask
    end
  end

  @[AlwaysInline]
  private def iter_search(hash, key)
    return if empty?
    if indexmask(@format) == 0
      @first.upto(@last - 1) do |idx|
        yield idx unless @hashes[idx] == 0
      end
    else
      iter_index(hash) do |pos|
        idx = @index[pos]
        break if idx == 0
        idx -= 1
        yield idx unless @hashes[idx] == 0
      end
    end
  end

  protected def find_entry(hash, key) : {Pointer(Entry(K, V)), UInt32}
    iter_search(hash, key) do |idx|
      if @hashes[idx] == hash && @entries[idx].key == key
        return @entries + idx, idx
      end
    end
    {Pointer(Entry(K, V)).new(0), 0_u32}
  end

  def rehash
    @rebuild_num += 1_u16
    if needs_shrink(@size, @format)
      reclaim_without_index
      if needs_shrink(@size, @format - 1)
        resize_data(@format - 1)
      end
      if indexmask(@format) != 0
        fix_index
      end
    elsif nentries(@format + 1) == 0
      raise "Hash table too big"
    else
      resize_data(@format + 1)
      if indexmask(@format) != indexmask(@format - 1)
        reclaim_without_index
        fix_index
      end
    end
  end

  private def resize_data(newsz)
    oldsz = @format
    old_nindex = nindex(oldsz)
    new_nindex = nindex(newsz)
    old_nentries = nentries(oldsz)
    new_nentries = nentries(newsz)
    @hashes = @hashes.realloc(new_nentries)
    @entries = @entries.realloc(new_nentries)
    if new_nindex != old_nindex
      @index = @index.realloc(new_nindex)
    end
    if new_nentries > old_nentries
      (@entries + old_nentries).clear(new_nentries - old_nentries)
    end
    @format = newsz
  end

  private def needs_shrink(size : Int32, sz : UInt8) : Bool
    sz > 1 && size < nentries(sz)/2
  end

  private def reclaim_without_index
    @rebuild_num += 1_u16
    pos = 0_u32
    unless empty?
      idx = @first
      if @first == 0_u32
        if @last == @size
          pos = idx = @last
        else
          while @hashes[idx] != 0_u64
            idx += 1
          end
          pos = idx
        end
      end
      idx.upto(@last - 1) do |idx|
        unless @hashes[idx] == 0_u64
          @entries[pos] = @entries[idx]
          @hashes[pos] = @hashes[idx]
          pos += 1
        end
      end
    end
    (@entries + pos).clear(@last - pos)
    @first = 0_u32
    @last = pos
  end

  private def fix_index
    @index.clear(nindex(@format))
    return if empty?
    @first.upto(@last - 1) do |idx|
      insert_index_simple(idx)
    end
  end

  private def push_entry(hash : UInt64, key, val) : UInt32
    if @last == nentries(@format)
      rehash
    end
    idx = @last
    @hashes[idx] = hash
    entry = @entries + idx
    entry.value.key = key
    entry.value.value = val
    @last += 1
    @size += 1
    idx
  end

  protected def insert_index_simple(idx : UInt32)
    iter_index(@hashes[idx]) do |pos|
      if @index[pos] == 0
        @index[pos] = idx + 1
        break
      end
    end
  end

  protected def insert_index_reuse(idx : UInt32)
    return if indexmask(@format) == 0
    reuse = @size != @last
    iter_index(@hashes[idx]) do |pos|
      oidx = @index[pos]
      if oidx == 0 || (reuse && @hashes[oidx - 1] == 0_u64)
        @index[pos] = idx + 1
        break
      end
    end
  end

  private def delete_idx(idx)
    @hashes[idx] = 0_u64
    (@entries + idx).clear
    @size -= 1
    if @first == idx
      if @size == 0
        @first = @last
      else
        idx += 1
        while @hashes[idx] == 0_u64
          idx += 1
        end
        @first = idx
      end
    end
  end

  def hash_key(key)
    h = key.hash.to_u64
    (h >> 1) + 1
  end

  private def nindex(sz)
    mask = FORMATS[sz].indexmask
    mask + (mask != 0 ? 1 : 0)
  end

  private def indexmask(sz)
    FORMATS[sz].indexmask
  end

  private def nentries(sz)
    FORMATS[sz].nentries
  end

  private def calculate_new_size(size)
    (1...FORMATS.size).each do |i|
      return i.to_u8 if FORMATS[i].nentries >= size
    end
    raise "Hash table too big"
  end

  private struct Entry(K, V)
    property key : K
    property value : V
    property hash : UInt64

    def initialize(@key : K, @value : V, @hash : UInt64)
    end

    def pair : {K, V}
      {@key, @value}
    end
  end

  private module BaseIterator
    def initialize(@hash, @current, @rebuild_num)
    end

    def base_next
      if @hash.@rebuild_num != @rebuild_num
        raise "Hash modified during iteration"
      end
      while @current < @hash.@last
        if @hash.@hashes[@current] != 0_u64
          value = yield (@hash.@entries + @current)
          @current += 1_u32
          return value
        end
        @current += 1_u32
      end
      stop
    end

    def rewind
      @current = @hash.@first
    end
  end

  private class EntryIterator(K, V)
    include BaseIterator
    include Iterator({K, V})

    @hash : Hash(K, V)
    @current : UInt32
    @rebuild_num : UInt16

    def next
      base_next { |entry| {entry.value.key, entry.value.value} }
    end
  end

  private class KeyIterator(K, V)
    include BaseIterator
    include Iterator(K)

    @hash : Hash(K, V)
    @current : UInt32
    @rebuild_num : UInt16

    def next
      base_next &.value.key
    end
  end

  private class ValueIterator(K, V)
    include BaseIterator
    include Iterator(V)

    @hash : Hash(K, V)
    @current : UInt32
    @rebuild_num : UInt16

    def next
      base_next &.value.value
    end
  end

  # :nodoc:
  record Format, nentries : UInt32, indexmask : UInt32
  {% begin %}
  # :nodoc:
  FORMATS = StaticArray[
      Format.new(0_u32, 0_u32),
      Format.new(8_u32, 0_u32),
  {% for i in 4..30 %}
      {% p = 1 << i %}
      Format.new({{p}}_u32, {{p*2 - 1}}_u32),
      Format.new({{p + p/2}}_u32, {{p*2 - 1}}_u32),
  {% end %}
      Format.new(0_u32, 0_u32),
    ]
{% end %}
end
