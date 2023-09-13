# A `Hash`-like object that holds HTTP headers.
#
# Two headers are considered the same if their downcase representation is the same
# (in which `_` is the downcase version of `-`).
#
# NOTE: To use `Headers`, you must explicitly import it with `require "http/headers"`
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

  def initialize
    # We keep a Hash with String | Array(String) values because
    # the most common case is a single value and so we avoid allocating
    # memory for arrays.
    @hash = Hash(Key, String | Array(String)).new
  end

  def []=(key, value : String)
    check_invalid_header_content(value)

    @hash[wrap(key)] = value
  end

  def []=(key, value : Array(String))
    value.each { |val| check_invalid_header_content val }

    @hash[wrap(key)] = value
  end

  def [](key) : String
    values = @hash[wrap(key)]
    concat values
  end

  def []?(key) : String?
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
  def includes_word?(key, word) : Bool
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

  # Adds a header with *key* and *value* to the header set.  If a header with
  # *key* already exists in the set, *value* is appended to the existing header.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers.new
  # headers.add("Connection", "keep-alive")
  # headers["Connection"] # => "keep-alive"
  # headers.add("Connection", "Upgrade")
  # headers["Connection"] # => "keep-alive,Upgrade"
  # ```
  def add(key, value : String) : self
    check_invalid_header_content value
    unsafe_add(key, value)
    self
  end

  def add(key, value : Array(String)) : self
    value.each { |val| check_invalid_header_content val }
    unsafe_add(key, value)
    self
  end

  def add?(key, value : String) : Bool
    return false unless valid_value?(value)
    unsafe_add(key, value)
    true
  end

  def add?(key, value : Array(String)) : Bool
    value.each { |val| return false unless valid_value?(val) }
    unsafe_add(key, value)
    true
  end

  def fetch(key, default) : String?
    fetch(wrap(key)) { default }
  end

  def fetch(key, &)
    values = @hash[wrap(key)]?
    values ? concat(values) : yield key
  end

  def has_key?(key) : Bool
    @hash.has_key? wrap(key)
  end

  def empty? : Bool
    @hash.empty?
  end

  def delete(key) : String?
    values = @hash.delete wrap(key)
    values ? concat(values) : nil
  end

  def merge!(other) : self
    other.each do |key, value|
      self[wrap(key)] = value
    end
    self
  end

  # Equality operator.
  #
  # Returns `true` if *other* is equal to `self`.
  #
  # Keys are matched case-insensitive.
  # String values are treated equal to an array values with the same string as
  # single element.
  #
  # ```
  # HTTP::Headers{"Foo" => "bar"} == HTTP::Headers{"Foo" => "bar"}   # => true
  # HTTP::Headers{"Foo" => "bar"} == HTTP::Headers{"foo" => "bar"}   # => true
  # HTTP::Headers{"Foo" => "bar"} == HTTP::Headers{"Foo" => ["bar"]} # => true
  # HTTP::Headers{"Foo" => "bar"} == HTTP::Headers{"Foo" => "baz"}   # => false
  # ```
  def ==(other : self)
    # Adapts `Hash#==` to treat string values equal to a single element array.

    return false unless @hash.size == other.@hash.size

    other.@hash.each do |key, value|
      this_value = @hash.fetch(key) { return false }
      case {value, this_value}
      in {String, String}, {Array, Array}
        return false unless this_value == value
      in {String, Array}
        return false unless this_value.size == 1 && this_value.unsafe_fetch(0) == value
      in {Array, String}
        return false unless value.size == 1 && value.unsafe_fetch(0) == this_value
      end
    end
    true
  end

  # See `Object#hash(hasher)`
  def hash(hasher)
    # Adapts `Hash#hash` to ensure consistency with equality operator.

    # The hash value must be the same regardless of the
    # order of the keys.
    result = hasher.result

    @hash.each do |key, value|
      copy = hasher
      copy = key.hash(copy)
      if value.is_a?(Array)
        copy = value.hash(copy)
      else
        copy = 1.hash(copy)
        copy = value.hash(copy)
      end
      result &+= copy.result
    end

    result.hash(hasher)
  end

  def each(&)
    @hash.each do |key, value|
      yield({key.name, cast(value)})
    end
  end

  def get(key) : Array(String)
    cast @hash[wrap(key)]
  end

  def get?(key) : Array(String)?
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

  def same?(other : HTTP::Headers) : Bool
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
    pp.list("HTTP::Headers{", @hash.keys.sort_by!(&.name), "}") do |key|
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

  # Serializes headers according to the HTTP protocol.
  #
  # Prints a list of HTTP header fields in the format desribed in [RFC 7230 §3.2](https://www.rfc-editor.org/rfc/rfc7230#section-3.2),
  # with each field terminated by a CRLF sequence (`"\r\n"`).
  #
  # The serialization does *not* include a double CRLF sequence at the end.
  #
  # ```
  # headers = HTTP::Headers{"foo" => "bar", "baz" => %w[qux qox]}
  # headers.serialize # => "foo: bar\r\nbaz: qux\r\nbaz: qox\r\n"
  # ```
  def serialize : String
    String.build do |io|
      serialize(io)
    end
  end

  # :ditto:
  def serialize(io : IO) : Nil
    each do |name, values|
      values.each do |value|
        io << name << ": " << value << "\r\n"
      end
    end
  end

  def valid_value?(value) : Bool
    invalid_value_char(value).nil?
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
end
