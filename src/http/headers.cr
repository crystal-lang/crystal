# A `Hash`-like object that holds HTTP headers.
#
# Two headers are considered the same if their downcase representation is the same
# (in which `_` is the downcase version of `-`).
struct HTTP::Headers
  include Enumerable({String, Array(String)})

  # :nodoc:
  record Key, name : String do
    forward_missing_to @name

    def hash(hasher)
      name.each_byte do |c|
        hasher = normalize_byte(c).hash(hasher)
      end
      hasher
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

      true
    end

    private def normalize_byte(byte)
      char = byte.unsafe_chr

      return byte if char.ascii_lowercase? || char == '-' # Optimize the common case
      return byte + 32 if char.ascii_uppercase?
      return '-'.ord if char == '_'

      byte
    end
  end

  # Determines whethere these headers are in read-only mode.
  # When in read-only mode, trying to modify these headers will
  # raise `ReadOnlyError`.
  property? read_only = false

  def initialize
    # We keep a Hash with String | Array(String) values because
    # the most common case is a single value and so we avoid allocating
    # memory for arrays.
    @hash = Hash(Key, String | Array(String)).new
  end

  def []=(key, value : String)
    check_writeable
    check_invalid_header_content(value)

    @hash[wrap(key)] = value
  end

  def []=(key, value : Array(String))
    check_writeable
    value.each { |val| check_invalid_header_content val }

    @hash[wrap(key)] = value
  end

  def [](key)
    values = @hash[wrap(key)]
    concat values
  end

  def []?(key)
    fetch(key, nil)
  end

  # Returns if among the headers for *key* there is some that contains *word* as a value.
  # The *word* is expected to match between word boundaries (i.e. non-alphanumeric chars).
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"Connection" => "keep-alive, Upgrade"}
  # headers.includes_word?("Connection", "Upgrade") # => true
  # ```
  def includes_word?(key, word)
    return false if word.empty?

    values = @hash[wrap(key)]?
    case values
    when Nil
      false
    when String
      includes_word_in_header_value?(word.downcase, values.downcase)
    else
      word = word.downcase
      values.any? do |value|
        includes_word_in_header_value?(word, value.downcase)
      end
    end
  end

  private def includes_word_in_header_value?(word, value)
    offset = 0
    while true
      start = value.index(word, offset)
      return false unless start
      offset = start + word.size

      # check if the match is not surrounded by alphanumeric chars
      next if start > 0 && value[start - 1].ascii_alphanumeric?
      next if start + word.size < value.size && value[start + word.size].ascii_alphanumeric?
      return true
    end

    false
  end

  def add(key, value : String)
    check_writeable
    check_invalid_header_content value
    unsafe_add(key, value)
    self
  end

  def add(key, value : Array(String))
    check_writeable
    value.each { |val| check_invalid_header_content val }
    unsafe_add(key, value)
    self
  end

  def add?(key, value : String)
    check_writeable
    return false unless valid_value?(value)
    unsafe_add(key, value)
    true
  end

  def add?(key, value : Array(String))
    check_writeable
    value.each { |val| return false unless valid_value?(val) }
    unsafe_add(key, value)
    true
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
    check_writeable
    values = @hash.delete wrap(key)
    values ? concat(values) : nil
  end

  def merge!(other)
    check_writeable
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
      case {value, this_value}
      when {String, String}
        return false unless value == this_value
      when {Array, Array}
        return false unless value == this_value
      when {String, Array}
        return false unless this_value.size == 1 && this_value[0] == value
      when {Array, String}
        return false unless value.size == 1 && value[0] == this_value
      else
        return false unless value.nil?
      end
    end

    true
  end

  def each
    @hash.each do |key, value|
      yield({key.name, cast(value)})
    end
  end

  def get(key)
    cast @hash[wrap(key)]
  end

  def get?(key)
    @hash[wrap(key)]?.try { |value| cast(value) }
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

  def to_s(io : IO) : Nil
    io << "HTTP::Headers{"
    @hash.each_with_index do |(key, values), index|
      io << ", " if index > 0
      key.name.inspect(io)
      io << " => "
      case values
      when Array
        if values.size == 1
          values.first.inspect(io)
        else
          values.inspect(io)
        end
      else
        values.inspect(io)
      end
    end
    io << '}'
  end

  def inspect(io : IO) : Nil
    to_s(io)
  end

  def pretty_print(pp)
    pp.list("HTTP::Headers{", @hash.keys.sort_by(&.name), "}") do |key|
      pp.group do
        key.name.pretty_print(pp)
        pp.text " =>"
        pp.nest do
          pp.breakable
          values = get(key)
          if values.size == 1
            values.first.pretty_print(pp)
          else
            values.pretty_print(pp)
          end
        end
      end
    end
  end

  def valid_value?(value)
    return invalid_value_char(value).nil?
  end

  forward_missing_to @hash

  private def unsafe_add(key, value : String)
    key = wrap(key)
    existing = @hash[key]?
    if existing
      if existing.is_a?(Array)
        existing << value
      else
        @hash[key] = [existing, value]
      end
    else
      @hash[key] = value
    end
  end

  private def unsafe_add(key, value : Array(String))
    key = wrap(key)
    existing = @hash[key]?
    if existing
      if existing.is_a?(Array)
        existing.concat value
      else
        new_value = [existing]
        new_value.concat(value)
        @hash[key] = new_value
      end
    else
      @hash[key] = value
    end
  end

  private def wrap(key)
    key.is_a?(Key) ? key : Key.new(key)
  end

  private def cast(value : String)
    [value]
  end

  private def cast(value : Array(String))
    value
  end

  private def concat(values : String)
    values
  end

  private def concat(values : Array(String))
    case values.size
    when 0
      ""
    when 1
      values.first
    else
      values.join ","
    end
  end

  private def check_invalid_header_content(value)
    if char = invalid_value_char(value)
      raise ArgumentError.new("Header content contains invalid character #{char.inspect}")
    end
  end

  private def valid_char?(char)
    # According to RFC 7230, characters accepted as HTTP header
    # are '\t', ' ', all US-ASCII printable characters and
    # range from '\x80' to '\xff' (but the last is obsoleted.)
    return true if char == '\t'
    if char < ' ' || char > '\u{ff}' || char == '\u{7f}'
      return false
    end
    true
  end

  private def invalid_value_char(value)
    value.each_byte do |byte|
      unless valid_char?(char = byte.unsafe_chr)
        return char
      end
    end
  end

  private def check_writeable
    if read_only?
      raise ReadOnlyError.new("HTTP::Headers are in read-only mode (it probably means the HTTP::Server headers were already sent)")
    end
  end
end
