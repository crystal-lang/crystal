struct HTTP::Headers
  def initialize
    @hash = {} of String => Array(String)
  end

  def []=(key, value : String)
    self[key] = [value]
  end

  def []=(key, value : Array(String))
    @hash[key_name(key)] = value
  end

  def [](key)
    fetch key
  end

  def []?(key)
    values = @hash[key_name(key)]?
    values ? concat(values) : nil
  end

  def add(key, value : String)
    existing = @hash[key_name(key)]?
    if existing
      existing << value
    else
      @hash[key_name(key)] = [value]
    end
    self
  end

  def add(key, value : Array(String))
    existing = @hash[key_name(key)]?
    if existing
      existing.concat value
    else
      @hash[key_name(key)] = value
    end
    self
  end

  def fetch(key)
    values = @hash.fetch key_name(key)
    concat values
  end

  def fetch(key, default)
    fetch(key) { default }
  end

  def fetch(key)
    k = key_name(key)
    values = @hash[k]?
    values ? concat(values) : yield k
  end

  def has_key?(key)
    @hash.has_key? key_name(key)
  end

  def empty?
    @hash.empty?
  end

  def delete(key)
    values = @hash.delete key_name(key)
    values ? concat(values) : nil
  end

  def merge!(other)
    other.each do |key, value|
      self[key] = value
    end
  end

  def ==(other : self)
    self == other.@hash
  end

  def ==(other : Hash)
    return false unless @hash.length == other.length

    other.each do |key, value|
      this_value = @hash[key_name(key)]?
      if this_value
        case value
        when String
          return false unless this_value.length == 1 && this_value[0] == value
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

  def get(key)
    @hash[key_name(key)]
  end

  def get?(key)
    @hash[key_name(key)]?
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

  def to_s(io : IO)
    io << "HTTP::Headers{"
    @hash.each_with_index do |key, values, index|
      io << ", " if index > 0
      key.inspect(io)
      io << " => "
      if values.length == 1
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

  private def key_name(key)
    key.capitalize
  end

  private def cast(value : String)
    [value]
  end

  private def cast(value : Array(String))
    value
  end

  private def concat(values)
    case values.length
    when 0
      ""
    when 1
      values.first
    else
      values.join ","
    end
  end
end
