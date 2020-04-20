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

    # Returns true if the normalized name of self is the same as the normalized value passed.
    def ==(key2 : HTTP::Headers::Key) : Bool
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

  # Sets the value of key to the given value.
  # ArgumentError will be raised if header includes invalid characters.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.or"}
  # headers["host"] = "crystal-lang.org"
  # headers["accept"] = "text/html"
  # headers #=> HTTP::Headers{"host" => "crystal-lang.org", "accept" => "http/html"}
  # ```
  def []=(key : String, value : String) : String
    check_invalid_header_content(value)

    @hash[wrap(key)] = value
  end

  # Sets the value of key to the given value.
  # ArgumentError will be raised if header includes invalid characters.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers["host"] = ["crystal-lang.org", "play.crystal-lang.org"]
  # headers #=> HTTP::Headers{"host" => ["crystal-lang.org", "play.crystal-lang.org"]}
  # headers["accept"] = ["text/html", "application/json"]
  # headers #=> HTTP::Headers{"host" => ["crystal-lang.org", "play.crystal-lang.org"], "accept" => ["text/html", "application/json"]}
  # ```
  def []=(key : String, value : Array(String)) : Array(String)
    value.each { |val| check_invalid_header_content val }

    @hash[wrap(key)] = value
  end

  # Returns the value for the key given by key.  If no value found a KeyError will be raised.
  # ArgumentError will be raised if header includes invalid characters.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org", "accept" => ["text/html", "application/json"]}
  # headers["host"]   #=> "crystal-lang.org"
  # headers["accept"] #=> "text/html,application/json"
  # headers["accept-encoding"] #=> raises KeyError
  # ```
  def [](key : HTTP::Headers::Key | String) : String
    values = @hash[wrap(key)]
    concat values
  end

  # Returns the value for the key given by key. If not found, returns nil.
  # ArgumentError will be raised if header includes invalid characters.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org", "accept" => ["text/html", "application/json"]}
  # headers["host"]?            #=> "crystal-lang.org"
  # headers["accept"]?          #=> "text/html,application/json"
  # headers["accept-encoding"]? #=> nil
  # ```
  def []?(key : HTTP::Headers::Key | String) : String?
    fetch(key, nil).as(String?)
  end

  # Returns if among the headers for *key* there is some that contains *word* as a value.
  # The *word* is expected to match between word boundaries (i.e. non-alphanumeric chars).
  #
  # ```
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

  # Inserts a key value pair into the header collection and returns the value of the added key.  If a key already exists the value is turned into an array.
  # ArgumentError will be raised if header includes invalid characters.
  #
  # ```
  # headers = HTTP::Headers.new
  # headers.add("host", "crystal-lang.org"       #=> HTTP::Headers{"host" => "crystal-lang.org"}
  # headers.add("host", "play.crystal-lang.org") #=> HTTP::Headers{"host" => ["crystal-lang.org", "play.crystal-lang.org"]}
  # headers["host"]                              #=> "crystal-lang.org,play.crystal-lang.org"
  # ```
  def add(key, value : String) : self
    check_invalid_header_content(value)
    unsafe_add(key, value)
    self
  end

  # Inserts a key value pair into the header collection and returns the value of the added key.
  # ArgumentError will be raised if header includes invalid characters.
  #
  # ```
  # headers = HTTP::Headers.new
  # headers.add("host", ["crystal-lang.org", "play.crystal-lang.org"]) #=> HTTP::Headers{"host" => ["crystal-lang.org", "play.crystal-lang.org"]}
  # headers["host"]                                                    #=> "crystal-lang.org,play.crystal-lang.org"
  # ```
  def add(key, value : Array(String)) : self
    value.each { |val| check_invalid_header_content val }
    unsafe_add(key, value)
    self
  end

  # Inserts a key value pair into the header collection and returns true if the pair was added.
  # ArgumentError will be raised if header includes invalid characters.
  #
  # ```
  # headers = HTTP::Headers.new
  # headers.add?("host", "crystal-lang.org")
  # headers["host"] #=> "crystal-lang.org"
  # ```
  def add?(key, value : String) : Bool
    return false unless valid_value?(value)
    unsafe_add(key, value)
    true
  end

  # Inserts a key value pair into the header collection and returns true if the pair was added.
  # ArgumentError will be raised if header includes invalid characters.
  #
  # ```
  # headers = HTTP::Headers.new
  # headers.add?("accept-encoding", ["text/html", "application/json"])
  # headers["accept-encoding"] #=> "text/html,application/json"
  # ```
  def add?(key, value : Array(String)) : Bool
    value.each { |val| return false unless valid_value?(val) }
    unsafe_add(key, value)
    true
  end

  # Fetches a value for given key, or when not found the value given by default.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers.fetch("host", "foo") #=> "crystal-lang.org"
  # headers.fetch("accept-encoding", "foo") #=> "foo"
  # ```
  def fetch(key : HTTP::Headers::Key | String, default : T) forall T
    fetch(wrap(key)) { default }
  end

  # Fetches a value for given key, otherwise executes the given block with the index and returns its value.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers.fetch("host") { "crystal-lang.org" } #=> "crystal-lang.org"
  # headers.fetch("accept-encoding") { "foo" }   #=> "foo"
  # ```
  def fetch(key : String)
    values = @hash[wrap(key)]?
    values ? concat(values) : yield key
  end

  # Returns true if the header named key exists and false if it doesn't.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers.has_key?("host")            #=> true
  # headers.has_key?("accept-encoding") #=> false
  # ```
  def has_key?(key) : Bool
    @hash.has_key? wrap(key)
  end

  # returns true if there are no key value pairs
  # ```
  # headers = HTTP::Headers.new
  # headers.empty? #=> true
  # headers.add("host", "crystal-lang.org")
  # headers.empty? #=> false
  # ```
  def empty? : Bool
    @hash.empty?
  end

  # Removes the header named key. Returns the previous value if the header key existed, otherwise returns nil.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers.delete("host")            #=> "crystal-lang.org"
  # headers.delete("accept-encoding") #=> nil
  # ```
  def delete(key) : String?
    values = @hash.delete wrap(key)
    values ? concat(values) : nil
  end

  # Mofifies self with the keys and values of these headers and other combined
  #
  # ```
  # headers1 = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers2 = HTTP::Headers{"accept-encoding" => "text/html"}
  # headers1.merge!(headers2) #=> HTTP::Headers{"host" => "crystal-lang.org", "accept-encoding" => "text/html"}
  # ```
  #
  # A hash can be used as well
  #
  # ```
  # headers1 = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers_hash = {"accept-encoding" => "text/html"}
  # headers1.merge!(headers_hash) #=> HTTP::Headers{"host" => "crystal-lang.org", "accept-encoding" => "text/html"}
  # ```
  def merge!(other) : self
    other.each do |key, value|
      self[wrap(key)] = value
    end
    self
  end

  # Compares with other. Returns true if headers are the same.
  #
  # ```
  # headers1 = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers2 = HTTP::Headers{"accept-encoding" => "text/html"}
  #
  # headers1 == headers1     #=> true
  # headers1 == headers2     #=> false
  # ```
  def ==(other : self) : Bool
    self == other.@hash
  end

  # Compares with other. Returns true if all key-value pairs are the same.
  #
  # ```
  # headers1 = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers2 = HTTP::Headers{"host" => ["crystal-lang.org", "play.crystal-lang.org"]}
  # headers_hash1 = {"host" => "crystal-lang.org"}
  # headers_hash2 = {"host" => ["crystal-lang.org", "play.crystal-lang.org"]}
  #
  # headers1 == headers1      #=> true
  # headers1 == headers_hash1 #=> true
  # headers1 == headers_hash2 #=> false
  # headers2 == headers_hash2 #=> true
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

  # Returns an iterator over the header keys. Which behaves like an Iterator returning a Tuple consisting of the header key and value.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org", "accept-encoding" => "text/html"}
  # iterator = headers.each
  #
  # iterator.next #=> {HTTP::Headers::Key(@name="host"), "crystal-lang.org"}
  # iterator.next #=> {HTTP::Headers::Key(@name="accept-encoding"), "text/html"}
  # ```
  #
  # A block can also be passed to each as well
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org", "accept-encoding" => "text/html"}
  # header_hash = {} of String => String
  #
  # headers.each do |key, value|
  #   header_hash[key] = value.first
  # end
  #
  # header_hash #=> {"host" => "crystal-lang.org", "accept-encoding" => "text/html"}
  # ```
  #
  # The enumeration follows the order the keys were inserted.
  def each : Nil
    @hash.each do |key, value|
      yield({key.name, cast(value)})
    end
  end

  # Gets a value for given key and casts the value as an Array of Strings. If no value found a KeyError will be raised.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org", "accept-encoding" => ["text/html", "application/json"]}
  # headers.get("host")            #=> ["crystal-lang.org"]
  # headers.get("accept-encoding") #=> ["text/text", "application/json"]
  # headers.get("cache-control")   #=> raises KeyError
  # ```
  def get(key) : Array(String) | String
    cast @hash[wrap(key)]
  end

  # Gets a value for given key and casts the value as an Array of Strings. If no value found a nil will be returned.
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org", "accept-encoding" =["text/html", "application/json"]}
  # headers.get("host")            #=> ["crystal-lang.org"]
  # headers.get("accept-encoding") #=> ["text/html", "application/json"]
  # headers.get("connection")      #=> nil
  # ```
  def get?(key) : (Array(String) | String)?
    @hash[wrap(key)]?.try { |value| cast(value) }
  end

  # Duplicates the headers
  #
  # ```
  # headers = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers.dup #=> HTTP::Headers{"host" => "crystal-lang.org"}
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

  # Checks to see if the headers are same object in memory
  #
  # ```
  # headers1 = HTTP::Headers{"host" => "crystal-lang.org"}
  # headers2 = HTTP::Headers{"host" => "crystal-lang.org"}
  #
  # headers1.same?(headers1) #=> true
  # headers1.same?(headers2) #=> false
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

  # Returns true if the value complies with RFC 7230 valid characters, otherwise it returns false.
  #
  # ```
  # headers = HTTP::Headers.new
  # headers.valid_value? "host"       #=> true
  # headers.valid_value? "ho\u{11}st" #=> false
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

  private def invalid_value_char(value) : Char?
    value.each_byte do |byte|
      unless valid_char?(char = byte.unsafe_chr)
        return char
      end
    end
  end
end
