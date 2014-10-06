struct HTTP::Headers
  def initialize
    @hash = {} of String => String
  end

  def []=(key, value)
    @hash[key_name(key)] = value.to_s
  end

  def [](key)
    fetch key
  end

  def []?(key)
    @hash[key_name(key)]?
  end

  def fetch(key)
    @hash.fetch key_name(key)
  end

  def fetch(key, default)
    @hash.fetch key_name(key), default
  end

  def fetch(key)
    @hash.fetch(key_name(key)) { |k| yield k }
  end

  def has_key?(key)
    @hash.has_key? key_name(key)
  end

  def empty?
    @hash.empty?
  end

  def delete(key)
    @hash.delete key_name(key)
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
      return false unless @hash[key_name(key)]? == value
    end

    true
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

  macro method_missing(name, args, block)
    @hash.{{name.id}}({{args.argify}}) {{block}}
  end

  private def key_name(key)
    key.capitalize
  end
end
