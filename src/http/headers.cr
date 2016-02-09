# A `Hash`-like object that holds HTTP headers.
#
# Two headers are considered the same if their downcase representation is the same
# (in which `_` is the downcase version of `-`).
struct HTTP::Headers
  # :nodoc:
  record Key, name do
    forward_missing_to @name

    def hash
      h = 0
      name.each_byte do |c|
        c = normalize_byte(c)
        h = 31 * h + c
      end
      h
    end

    def ==(key2)
      key1 = name
      key2 = key2.name

      return false if key1.bytesize != key2.bytesize

      cstr1 = key1.to_unsafe
      cstr2 = key2.to_unsafe

      key1.bytesize.times do |i|
        next if cstr1[i] == cstr2[i] # Optimize the common case

        byte1 = normalize_byte(cstr1[i])
        byte2 = normalize_byte(cstr2[i])

        return false if byte1 != byte2
      end
    end

    private def normalize_byte(byte)
      char = byte.chr

      return byte if 'a' <= char <= 'z' || char == '-' # Optimize the common case
      return byte + 32 if 'A' <= char <= 'Z'
      return '-'.ord if char == '_'

      byte
    end
  end

  def initialize
    @hash = Hash(Key, Array(String)).new
  end

  def []=(key, value : String)
    self[wrap(key)] = [value]
  end

  def []=(key, value : Array(String))
    @hash[wrap(key)] = value
  end

  def [](key)
    fetch wrap(key)
  end

  def []?(key)
    values = @hash[wrap(key)]?
    values ? concat(values) : nil
  end

  def add(key, value : String)
    key = wrap(key)
    existing = @hash[key]?
    if existing
      existing << value
    else
      @hash[key] = [value]
    end
    self
  end

  def add(key, value : Array(String))
    key = wrap(key)
    existing = @hash[key]?
    if existing
      existing.concat value
    else
      @hash[key] = value
    end
    self
  end

  def fetch(key)
    values = @hash.fetch wrap(key)
    concat values
  end

  def fetch(key, default)
    fetch(wrap(key)) { default }
  end

  def fetch(key)
    values = @hash[wrap(key)]?
    values ? concat(values) : yield key
  end

  def has_key?(key)
    @hash.has_key? wrap(key)
  end

  def empty?
    @hash.empty?
  end

  def delete(key)
    values = @hash.delete wrap(key)
    values ? concat(values) : nil
  end

  def merge!(other)
    other.each do |key, value|
      self[wrap(key)] = value
    end
    self
  end

  def ==(other : self)
    self == other.@hash
  end

  def ==(other : Hash)
    return false unless @hash.size == other.size

    other.each do |key, value|
      this_value = @hash[wrap(key)]?
      if this_value
        case value
        when String
          return false unless this_value.size == 1 && this_value[0] == value
        when Array(String)
          return false unless this_value == value
        else
          false
        end
      else
        return false unless value.nil?
      end
    end

    true
  end

  def each
    @hash.each do |key, value|
      yield key.name, value
    end
  end

  def get(key)
    @hash[wrap(key)]
  end

  def get?(key)
    @hash[wrap(key)]?
  end

  def dup
    dup = HTTP::Headers.new
    @hash.each do |key, value|
      dup.@hash[key] = value
    end
    dup
  end

  def clone
    dup
  end

  def same?(other : HTTP::Headers)
    object_id == other.object_id
  end

  def to_s(io : IO)
    io << "HTTP::Headers{"
    @hash.each_with_index do |key, values, index|
      io << ", " if index > 0
      key.name.inspect(io)
      io << " => "
      if values.size == 1
        values.first.inspect(io)
      else
        values.inspect(io)
      end
    end
    io << "}"
  end

  def inspect(io : IO)
    to_s(io)
  end

  forward_missing_to @hash

  private def wrap(key)
    key.is_a?(Key) ? key : Key.new(key)
  end

  private def cast(value : String)
    [value]
  end

  private def cast(value : Array(String))
    value
  end

  private def concat(values)
    case values.size
    when 0
      ""
    when 1
      values.first
    else
      values.join ","
    end
  end
end
