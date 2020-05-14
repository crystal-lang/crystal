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

    # Returns `true` if the normalized name of `self` is the same as the normalized value passed.
    #
    # ```
    # require "http/headers"
    #
    # key1 = HTTP::Headers::Key.new("host")
    # key2 = HTTP::Headers::Key.new("HOST")
    # key1 == key2 # => true
    # ```
    def ==(key2 : Key) : Bool
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

  # Sets the value of *key* header to *value*.
  #
  # Previous values are overridden.
  # Raises `ArgumentError` if *value* includes invalid characters.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers["host"] = "play.crystal-lang.org"
  # headers # => HTTP::Headers{"host" => "play.crystal-lang.org"}
  # headers["accept-encoding"] = ["text/html", "application/json"]
  # headers # => HTTP::Headers{"host" => "play.crystal-lang.org", "accept-encoding" => ["text/html", "application/json"]}
  # ```
  def []=(key : String, value : String) : String
    check_invalid_header_content(value)

    @hash[wrap(key)] = value
  end

  # Sets the value of *key* header to *value*.
  #
  # Previous values are overridden.
  # `ArgumentError` will be raised if header includes invalid characters.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers["host"] = ["crystal-lang.org", "play.crystal-lang.org"]
  # headers # => HTTP::Headers{"host" => ["crystal-lang.org", "play.crystal-lang.org"]}
  # headers["accept-encoding"] = ["text/html", "application/json"]
  # headers # => HTTP::Headers{"host" => ["crystal-lang.org", "play.crystal-lang.org"], "accept-encoding" => ["text/html", "application/json"]}
  # ```
  def []=(key : String, value : Array(String)) : Array(String)
    value.each { |val| check_invalid_header_content val }

    @hash[wrap(key)] = value
  end

  # Returns the value of *key* header.
  #
  # In case of multiple values, they are returned as a comma-separated string.
  # If no value found a `KeyError` will be raised.  `ArgumentError` will be raised if header includes invalid characters.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "crystal-lang.org", "accept-encoding" => ["text/html", "application/json"]}
  # headers["host"]            # => "crystal-lang.org"
  # headers["accept-encoding"] # => "text/html,application/json"
  # headers["user-agent"]      # => raises KeyError
  # ```
  def [](key : HTTP::Headers::Key | String) : String
    values = @hash[wrap(key)]
    concat values
  end

  # Returns the value for the key given by key. If not found, returns `nil`.
  # `ArgumentError` will be raised if header includes invalid characters.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "crystal-lang.org", "accept-encoding" => ["text/html", "application/json"]}
  # headers["host"]?            # => "crystal-lang.org"
  # headers["accept-encoding"]? # => "text/html,application/json"
  # headers["user-agent"]?      # => nil
  # ```
  def []?(key : HTTP::Headers::Key | String) : String?
    fetch(key, nil).as(String?) # TODO: fixup
  end

  # Returns if among the headers for *key* there is some that contains *word* as a value.
  # The *word* is expected to match between word boundaries (i.e. non-alphanumeric chars).
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"accept-encoding" => "text/html,application/json"}
  # headers.includes_word?("accept-encoding", "text/html") # => true
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

  private def includes_word_in_header_value?(word, value) : Bool
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

  # Appends a value to the key of a header and returns `self`.  If there is an existing value for the key the value will be converted to an `Array`
  # `ArgumentError` will be raised if header includes invalid characters.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"accept-encoding" => "text/html"}
  # headers.add("accept-encoding", "application/json") # => HTTP::Headers{"accept-encoding" => ["text/html", "application/json"]}
  # ```
  def add(key, value : String) : self
    check_invalid_header_content(value)
    unsafe_add(key, value)
    self
  end

  # Inserts a key-value pair into the header collection and returns `self`.
  # `ArgumentError` will be raised if header includes invalid characters.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers.new
  # headers.add("accept-encoding", ["text/html", "application/json"]) # => HTTP::Headers{"accept-encoding" => ["text/html", "application/json"]}
  # ```
  def add(key, value : Array(String)) : self
    value.each { |val| check_invalid_header_content val }
    unsafe_add(key, value)
    self
  end

  # Attempts to insert a header at the *key* into the headers. Returns `true` if the *value* is valid and `false` otherwise.
  # raises `ArgumentError`  if header includes invalid characters.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers.new
  # headers.add?("host", "crystal-lang.org") # => true
  # headers["host"]                          # => "bar"
  # ```
  def add?(key, value : String) : Bool
    return false unless valid_value?(value)
    unsafe_add(key, value)
    true
  end

  # Inserts a key value pair into the header collection and returns `true` if the pair was added.
  # `ArgumentError` will be raised if header includes invalid characters.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers.new
  # headers.add?("accept-encoding", ["text/html", "application/json"]) # => true
  # headers["accept-encoding"]                                         # => "text/html,application/json"
  # ```
  def add?(key, value : Array(String)) : Bool
    value.each { |val| return false unless valid_value?(val) }
    unsafe_add(key, value)
    true
  end

  # Returns the value for a given *key* or *default* if not found.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "play.crystal-lang.com"}
  # headers.fetch("host", "crystal-lang.org")      # => "play.crystal-lang.org"
  # headers.fetch("content-encoding", "text/html") # => "text/html"
  # ```
  def fetch(key : HTTP::Headers::Key | String, default : T) forall T
    fetch(wrap(key)) { default }
  end

  # Fetches a value for given key, otherwise executes the given block and returns its value.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "play.crystal-lang.org"}
  # headers.fetch("host") { "crystal-lang.org" }      # => "crystal-lang.org"
  # headers.fetch("content-encoding") { "text/html" } # => "text/html"
  # ```
  def fetch(key : String, & : String ->)
    values = @hash[wrap(key)]?
    values ? concat(values) : yield key
  end

  # Returns `true` if the header named key exists and `false` if it doesn't.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "play.crystal-lang.org"}
  # headers.has_key?("host")             # => true
  # headers.has_key?("content-encoding") # => false
  # ```
  def has_key?(key) : Bool
    @hash.has_key? wrap(key)
  end

  # Returns `true` if there are no key value pairs.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers.new
  # headers.empty? # => true
  # headers.add("host", "crystal-lang.org")
  # headers.empty? # => false
  # ```
  def empty? : Bool
    @hash.empty?
  end

  # Removes the header named key. Returns the previous value if the header key existed, otherwise returns `nil`.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers.delete("host")             # => "crystal-lang.org"
  # headers.delete("content-encoding") # => nil
  # ```
  def delete(key : String) : String?
    values = @hash.delete wrap(key)
    values ? concat(values) : nil
  end

  # Modifies `self` with the keys and values of these headers and other combined.
  #
  # ```
  # require "http/headers"
  #
  # headers1 = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers2 = HTTP::Headers{"content-encoding" => "text/html"}
  # headers1.merge!(headers2) # => HTTP::Headers{"host" => "crystal-lang.org", "content-encoding" => "text/html"}
  # ```
  #
  # A hash can be used as well.
  #
  # ```
  # require "http/headers"
  #
  # headers1 = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers_hash = {"content-encoding" => "text/html"}
  # headers1.merge!(headers_hash) # => HTTP::Headers{"host" => "crystal-lang.org", "content-encoding" => "text/html"}
  # ```
  def merge!(other) : self
    other.each do |key, value|
      self[wrap(key)] = value
    end
    self
  end

  # Returns `true` if other and `self` are equal.
  #
  # ```
  # require "http/headers"
  #
  # headers1 = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers2 = HTTP::Headers{"content-encoding" => "text/html"}
  #
  # headers1 == headers1 # => true
  # headers1 == headers2 # => false
  # ```
  def ==(other : self) : Bool
    self == other.@hash
  end

  # Returns `true` if the key-value pairs of `other` and `self` are equal.
  #
  # ```
  # require "http/headers"
  #
  # headers1 = HTTP::Headers{"host" => "text/html"}
  # headers2 = HTTP::Headers{"host" => ["text/html", "application/json"]}
  # headers_hash1 = {"host" => "text/html"}
  # headers_hash2 = {"host" => ["text/html", "application/json"]}
  #
  # headers1 == headers1      # => true
  # headers1 == headers_hash1 # => true
  # headers1 == headers_hash2 # => false
  # headers2 == headers_hash2 # => true
  # ```
  def ==(other : Hash) : Bool
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

  # Iterates over the headers yeilding each header as a `Tuple` of `String` and an `Array(String)`.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # header_hash = {} of String => Array(String)
  #
  # headers.each do |key, value|
  #   key   # => "host"
  #   value # => ["crystal-lang.org"]
  #   header_hash[key] = value
  # end
  #
  # header_hash # => {"host" => ["crystal-lang.org"]}
  # ```
  #
  # The enumeration follows the order the keys were inserted.
  def each : Nil
    @hash.each do |key, value|
      yield({key.name, cast(value)})
    end
  end

  # Returns the value for *key*. Single values are wrapped as `Array(String)`.
  # Raises `KeyError` if the key does not exist.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "crystal-lang.org", "accept-encoding" => ["text/html", "application/json"]}
  # headers.get("host")            # => ["crystal-lang.org"]
  # headers.get("accept-encoding") # => ["text/html", "application/json"]
  # headers.get("user-agent")      # raises KeyError
  # ```
  def get(key : String) : Array(String)
    cast @hash[wrap(key)]
  end

  # Returns the value for *key*. Single values are wrapped as `Array(String)`.
  # Returns `nil` if the key does not exist.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "crystal-lang.org", "accept-encoding" => ["text/html", "application/json"]}
  # headers.get("host")            # => ["crystal-lang.org"]
  # headers.get("accept-encoding") # => ["text/html", "application/json"]
  # headers.get("user-agent")      # => nil
  # ```
  def get?(key) : (Array(String) | String)?
    @hash[wrap(key)]?.try { |value| cast(value) }
  end

  # Duplicates the headers.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers.dup # => HTTP::Headers{"host" => "crystal-lang.org"}
  # ```
  def dup : self
    dup = HTTP::Headers.new
    @hash.each do |key, value|
      dup.@hash[key] = value
    end
    dup
  end

  # see HTTP::Headers#dup
  def clone : self
    dup
  end

  # Checks to see if the headers are same object in memory.
  #
  # ```
  # require "http/headers"
  #
  # headers1 = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers2 = HTTP::Headers{"host" => "crystal-lang.org"}
  #
  # headers1.same?(headers1) # => true
  # headers1.same?(headers2) # => false
  # ```
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

  def pretty_print(pp) : Nil
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

  # Returns `true` if the value complies with RFC 7230 valid characters, otherwise it returns `false`.
  #
  # ```
  # require "http/headers"
  #
  # headers = HTTP::Headers.new
  # headers.valid_value? "crystal-lang.org"       # => true
  # headers.valid_value? "crystal-\u{11}lang.org" # => false
  # ```
  def valid_value?(value) : Bool
    return invalid_value_char(value).nil?
  end

  forward_missing_to @hash

  private def unsafe_add(key, value : String) : Array(String) | String
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

  private def unsafe_add(key, value : Array(String)) : Array(String)
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

  private def wrap(key) : HTTP::Headers::Key
    key.is_a?(Key) ? key : Key.new(key)
  end

  private def cast(value : String) : Array(String)
    [value]
  end

  private def cast(value : Array(String)) : Array(String)
    value
  end

  private def concat(values : String) : String
    values
  end

  private def concat(values : Array(String)) : String
    case values.size
    when 0
      ""
    when 1
      values.first
    else
      values.join ","
    end
  end

  private def check_invalid_header_content(value) : Nil
    if char = invalid_value_char(value)
      raise ArgumentError.new("Header content contains invalid character #{char.inspect}")
    end
  end

  private def valid_char?(char) : Bool
    # According to RFC 7230, characters accepted as HTTP header
    # are '\t', ' ', all US-ASCII printable characters and
    # range from '\x80' to '\xff' (but the last is obsoleted.)
    return true if char == '\t'
    if char < ' ' || char > '\u{ff}' || char == '\u{7f}'
      return false
    end
    true
  end

  # TODO: should this return Nil
  private def invalid_value_char(value) : Char?
    value.each_byte do |byte|
      unless valid_char?(char = byte.unsafe_chr)
        return char
      end
    end
  end
end
