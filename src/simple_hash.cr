struct SimpleHash(K, V)
  def initialize
    @values = [] of {K, V}
  end

  def initialize(@values)
  end

  def [](key)
    fetch(key) do
      raise MissingKey.new "Missing hash value: #{key}"
    end
  end

  def []?(key)
    fetch(key) { nil }
  end

  def fetch(key)
    @values.each do |tuple|
      if tuple[0] == key
        return tuple[1]
      end
    end
    yield key
  end

  def []=(key : K, value : V)
    @values.each_with_index do |tuple, i|
      if tuple[0] == key
        @values[i] = {key, value}
        return value
      end
    end

    @values.push({key, value})
    value
  end

  def has_key?(key)
    @values.any? { |tuple| tuple[0] == key }
  end

  def delete(key)
    @values.each_with_index do |tuple, index|
      if tuple[0] == key
        return @values.delete_at(index)
      end
    end
    nil
  end

  def dup
    SimpleHash(K, V).new(@values.dup)
  end

  def each
    @values.each do |tuple|
      yield tuple[0], tuple[1]
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

  def keys
    @values.map { |tuple| tuple[0] }
  end

  def values
    @values.map { |tuple| tuple[1] }
  end

  def length
    @values.length
  end

  def object_id
    @values.object_id
  end
end
