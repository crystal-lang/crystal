struct SimpleHash(K, V)
  record Entry(K, V), key : K, value : V

  @values : Array(Entry(K, V))

  def initialize
    @values = [] of Entry(K, V)
  end

  def initialize(@values)
  end

  def [](key)
    fetch(key) do
      raise KeyError.new "Missing hash key: #{key.inspect}"
    end
  end

  def []?(key)
    fetch(key) { nil }
  end

  def fetch(key)
    @values.each do |entry|
      if entry.key == key
        return entry.value
      end
    end
    yield key
  end

  def []=(key : K, value : V)
    @values.each_with_index do |entry, i|
      if entry.key == key
        @values[i] = Entry.new(key, value)
        return value
      end
    end

    @values.push(Entry.new(key, value))
    value
  end

  def has_key?(key)
    @values.any? { |entry| entry.key == key }
  end

  def delete(key)
    @values.each_with_index do |entry, index|
      if entry.key == key
        return @values.delete_at(index)
      end
    end
    nil
  end

  def dup
    SimpleHash(K, V).new(@values.dup)
  end

  def each
    @values.each do |entry|
      yield entry.key, entry.value
    end
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

  # Iterates the given block for each element with an arbitrary object given, and returns the initially given object.
  # ```
  # evens = (1..10).each_with_object([] of Int32) { |i, a| a << i*2 }
  # # => [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
  # ```
  def each_with_object(memo)
    each do |k, v|
      yield(memo, k, v)
    end
    memo
  end

  def keys
    @values.map { |entry| entry.key }
  end

  def values
    @values.map { |entry| entry.value }
  end

  # Returns a new hash consisting of entries for which the block returns false.
  # ```
  # h = {"a" => 100, "b" => 200, "c" => 300}
  # h.reject { |k, v| k > "a" } # => {"a" => 100}
  # h.reject { |k, v| v < 200 } # => {"b" => 200, "c" => 300}
  # ```
  def reject(&block : K, V -> U)
    each_with_object(SimpleHash(K, V).new) do |memo, k, v|
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

  # Returns a new hash consisting of entries for which the block returns true.
  # ```
  # h = {"a" => 100, "b" => 200, "c" => 300}
  # h.select { |k, v| k > "a" } # => {"b" => 200, "c" => 300}
  # h.select { |k, v| v < 200 } # => {"a" => 100}
  # ```
  def select(&block : K, V -> U)
    reject { |k, v| !yield(k, v) }
  end

  # Equivalent to `Hash#select` but makes modification on the current object rather that returning a new one. Returns nil if no changes were made
  def select!(&block : K, V -> U)
    reject! { |k, v| !yield(k, v) }
  end

  def size
    @values.size
  end

  def object_id
    @values.object_id
  end

  def inspect(io : IO)
    to_s(io)
  end

  def to_s(io : IO)
    io << '{'
    @values.each_with_index do |entry, index|
      entry.key.inspect(io)
      io << " => "
      entry.value.inspect(io)
      io << ", " if index < @values.size - 1
    end
    io << '}'
  end
end
