class URI
  # Encodes *string* so it can be safely placed as a potentially multi-segmented
  # URI path, replacing special characters with URI escape sequences as needed.
  #
  # Unreserved characters such as ASCII letters, digits, and the characters
  # `_.-~` are not encoded, as well as the character `/` which represent a
  # segment separator in hierarchical paths ([RFC 3986 §3.3](https://datatracker.ietf.org/doc/html/rfc3986#section-3.3)).
  #
  # ```
  # require "uri"
  #
  # URI.encode_path("foo/bar/baz")  # => "foo/bar/baz"
  # URI.encode_path("hello world!") # => "hello%20world%21"
  # URI.encode_path("put: it+й")    # => "put%3A%20it%2B%D0%B9"
  # ```
  #
  # * `.decode` is the reverse operation.
  # * `.encode_path_segment` encodes a single path segment, escaping `/`.
  def self.encode_path(string : String) : String
    String.build { |io| encode_path(io, string) }
  end

  # :ditto:
  def self.encode_path(io : IO, string : String) : Nil
    self.encode(string, io) { |byte| URI.unreserved?(byte) || '/' === byte }
  end

  # Encodes *string* so it can be safely placed inside a URI path segment,
  # replacing special characters (including `/`) with URI escape sequences as needed.
  #
  # Unreserved characters such as ASCII letters, digits, and the characters
  # `_.-~` are not encoded (see `.unreserved?`).
  #
  # ```
  # require "uri"
  #
  # URI.encode_path_segment("foo;bar;baz")  # => "foo%3Bbar%3Bbaz"
  # URI.encode_path_segment("foo/bar/baz")  # => "foo%2Fbar%2Fbaz"
  # URI.encode_path_segment("foo,bar,baz")  # => "foo%2Cbar%2Cbaz"
  # URI.encode_path_segment("hello world!") # => "hello%20world%21"
  # URI.encode_path_segment("put: it+й")    # => "put%3A%20it%2B%D0%B9"
  # ```
  #
  # * `.decode` is the reverse operation.
  # * `.encode_path` encodes a path consisting of multiple segments, not escaping `/`.
  # * `.encode_www_form` escapes space character as `+`.
  def self.encode_path_segment(string : String) : String
    String.build { |io| encode_path_segment(io, string) }
  end

  # :ditto:
  def self.encode_path_segment(io : IO, string : String) : Nil
    self.encode(string, io) { |byte| URI.unreserved?(byte) }
  end

  # URL-decodes *string*.
  #
  # ```
  # require "uri"
  #
  # URI.decode("hello%20world!")                                 # => "hello world!"
  # URI.decode("put:%20it+%D0%B9")                               # => "put: it+й"
  # URI.decode("http://example.com/Crystal%20is%20awesome%20=)") # => "http://example.com/Crystal is awesome =)"
  # ```
  #
  # By default, `+` is decoded literally. If *plus_to_space* is `true`, `+` is
  # decoded as space character (`0x20`). Percent-encoded values such as `%20`
  # and `%2B` are always decoded as characters with the respective codepoint.
  #
  # ```
  # require "uri"
  #
  # URI.decode("peter+%2B+paul")                      # => "peter+++paul"
  # URI.decode("peter+%2B+paul", plus_to_space: true) # => "peter + paul"
  # ```
  #
  # * `.encode` is the reverse operation.
  # * `.decode_www_form` encodes plus to space by default.
  def self.decode(string : String, *, plus_to_space : Bool = false) : String
    if needs_decode?(string, plus_to_space: plus_to_space)
      String.build { |io| decode!(string, io, plus_to_space: plus_to_space) { false } }
    else
      string
    end
  end

  # URL-decodes a string and writes the result to *io*.
  #
  # See `.decode(string : String, *, plus_to_space : Bool = false) : String` for details.
  def self.decode(string : String, io : IO, *, plus_to_space : Bool = false) : Nil
    self.decode(string, io, plus_to_space: plus_to_space) { false }
  end

  # URL-encodes *string*.
  #
  # Reserved and unreserved characters are not escaped, so this only modifies some
  # special characters as well as non-ASCII characters. `.reserved?` and `.unreserved?`
  # provide more details on these character classes.
  #
  # ```
  # require "uri"
  #
  # URI.encode("hello world!")                             # => "hello%20world!"
  # URI.encode("put: it+й")                                # => "put:%20it+%D0%B9"
  # URI.encode("http://example.com/Crystal is awesome =)") # => "http://example.com/Crystal%20is%20awesome%20=)"
  # ```
  #
  # By default, the space character (`0x20`) is encoded as `%20` and `+` is
  # encoded literally. If *space_to_plus* is `true`, space character is encoded
  # as `+` and `+` is encoded as `%2B`:
  #
  # ```
  # require "uri"
  #
  # URI.encode("peter + paul")                      # => "peter%20+%20paul"
  # URI.encode("peter + paul", space_to_plus: true) # => "peter+%2B+paul"
  # ```
  #
  # * `.decode` is the reverse operation.
  # * `.encode_www_form` also escapes reserved characters.
  @[Deprecated("Use `.encode_path` instead.")]
  def self.encode(string : String, *, space_to_plus : Bool = false) : String
    String.build { |io| encode(string, io, space_to_plus: space_to_plus) }
  end

  # URL-encodes *string* and writes the result to *io*.
  #
  # See `.encode(string : String, *, space_to_plus : Bool = false) : String` for details.
  @[Deprecated("Use `.encode_path` instead.")]
  def self.encode(string : String, io : IO, *, space_to_plus : Bool = false) : Nil
    self.encode(string, io, space_to_plus: space_to_plus) { |byte| URI.reserved?(byte) || URI.unreserved?(byte) }
  end

  # URL-decodes *string* as [`x-www-form-urlencoded`](https://url.spec.whatwg.org/#urlencoded-serializing).
  #
  # ```
  # require "uri"
  #
  # URI.decode_www_form("hello%20world!")                           # => "hello world!"
  # URI.decode_www_form("put:%20it+%D0%B9")                         # => "put: it й"
  # URI.decode_www_form("http://example.com/Crystal+is+awesome+=)") # => "http://example.com/Crystal is awesome =)"
  # ```
  #
  # By default, `+` is decoded as space character (`0x20`). If *plus_to_space*
  # is `false`, `+` is decoded literally as `+`. Percent-encoded values such as
  # `%20` and `%2B` are always decoded as characters with the respective codepoint.
  #
  # ```
  # require "uri"
  #
  # URI.decode_www_form("peter+%2B+paul")                       # => "peter + paul"
  # URI.decode_www_form("peter+%2B+paul", plus_to_space: false) # => "peter+++paul"
  # ```
  #
  # * `.encode_www_form` is the reverse operation.
  # * `.decode` encodes plus literally by default.
  def self.decode_www_form(string : String, *, plus_to_space : Bool = true) : String
    decode(string, plus_to_space: plus_to_space)
  end

  # URL-decodes *string* as [`x-www-form-urlencoded`](https://url.spec.whatwg.org/#urlencoded-serializing)
  # and writes the result to *io*.
  #
  # See `self.decode_www_form(string : String, *, plus_to_space : Bool = true) : String`
  # for details.
  def self.decode_www_form(string : String, io : IO, *, plus_to_space : Bool = true) : Nil
    decode(string, io, plus_to_space: plus_to_space)
  end

  # URL-encodes *string* as [`x-www-form-urlencoded`](https://url.spec.whatwg.org/#urlencoded-serializing).
  #
  # Reserved characters are escaped, unreserved characters are not.
  # `.reserved?` and `.unreserved?` provide more details on these character
  # classes.
  #
  # ```
  # require "uri"
  #
  # URI.encode_www_form("hello world!")                             # => "hello+world%21"
  # URI.encode_www_form("put: it+й")                                # => "put%3A+it%2B%D0%B9"
  # URI.encode_www_form("http://example.com/Crystal is awesome =)") # => "http%3A%2F%2Fexample.com%2FCrystal+is+awesome+%3D%29"
  # ```
  #
  # The encoded string returned from this method can be used as name or value
  # components for a `application/x-www-form-urlencoded` format serialization.
  # `URI::Params` provides a higher-level API for this use case.
  #
  # By default, the space character (`0x20`) is encoded as `+` and `+` is encoded
  # as `%2B`. If *space_to_plus* is `false`, space character is encoded as `%20`
  # and `'+'` is encoded literally.
  #
  # ```
  # require "uri"
  #
  # URI.encode_www_form("peter + paul")                       # => "peter+%2B+paul"
  # URI.encode_www_form("peter + paul", space_to_plus: false) # => "peter%20%2B%20paul"
  # ```
  #
  # * `.decode_www_form` is the reverse operation.
  # * `.encode_path` escapes space character as `%20`.
  def self.encode_www_form(string : String, *, space_to_plus : Bool = true) : String
    String.build do |io|
      encode_www_form(string, io, space_to_plus: space_to_plus)
    end
  end

  # URL-encodes *string* as [`x-www-form-urlencoded`](https://url.spec.whatwg.org/#urlencoded-serializing)
  # and writes the result to *io*.
  #
  # See `.encode_www_form(string : String, *, space_to_plus : Bool = true)` for
  # details.
  def self.encode_www_form(string : String, io : IO, *, space_to_plus : Bool = true) : Nil
    encode(string, io, space_to_plus: space_to_plus) do |byte|
      URI.unreserved?(byte)
    end
  end

  # Returns whether given byte is reserved character defined in
  # [RFC 3986 §2.2](https://datatracker.ietf.org/doc/html/rfc3986#section-2.2).
  #
  # Reserved characters are ':', '/', '?', '#', '[', ']', '@', '!',
  # '$', '&', "'", '(', ')', '*', '+', ',', ';' and '='.
  def self.reserved?(byte) : Bool
    sub_delim?(byte) || gen_delim?(byte)
  end

  # :nodoc:
  # Returns `true` if the byte is URI gen-delims (https://datatracker.ietf.org/doc/html/rfc3986#section-2.2).
  def self.gen_delim?(byte)
    byte.unsafe_chr.in?('#', '/', ':', '?', '@', '[', ']')
  end

  # :nodoc:
  # Returns `true` if the byte is URI sub-delims (https://datatracker.ietf.org/doc/html/rfc3986#section-2.2).
  def self.sub_delim?(byte) : Bool
    char = byte.unsafe_chr
    '&' <= char <= ',' ||
      char.in?('!', '$', ';', '=')
  end

  # Returns whether given byte is unreserved character defined in
  # [RFC 3986 §2.3](https://datatracker.ietf.org/doc/html/rfc3986#section-2.3).
  #
  # Unreserved characters are ASCII letters, ASCII digits, `_`, `.`, `-` and `~`.
  def self.unreserved?(byte) : Bool
    char = byte.unsafe_chr
    char.ascii_alphanumeric? ||
      char.in?('_', '.', '-', '~')
  end

  # URL-decodes *string* and writes the result to *io*.
  #
  # The block is called for each percent-encoded ASCII character and determines
  # whether the value is to be decoded. When the return value is falsey,
  # the character is decoded. Non-ASCII characters are always decoded.
  #
  # By default, `+` is decoded literally. If *plus_to_space* is `true`, `+` is
  # decoded as space character (`0x20`).
  #
  # This method enables some customization, but typical use cases can be implemented
  # by either `.decode(string : String, *, plus_to_space : Bool = false) : String` or
  # `.decode_www_form(string : String, *, plus_to_space : Bool = true) : String`.
  def self.decode(string : String, io : IO, *, plus_to_space : Bool = false, &block) : Nil
    unless needs_decode?(string, plus_to_space: plus_to_space)
      io.write_string(string.to_slice)
      return
    end

    decode!(string, io, plus_to_space: plus_to_space) do |byte|
      yield byte
    end
  end

  # Similar to the above, but it assumes there will be chars to decode (% or +).
  private def self.decode!(string : String, io : IO, *, plus_to_space : Bool, &block) : Nil
    i = 0
    bytesize = string.bytesize

    if io.encoding == "UTF-8"
      target_io = io
    else
      io_memory = IO::Memory.new(bytesize)
      target_io = io_memory
    end

    while i < bytesize
      byte = string.to_unsafe[i]
      char = byte.unsafe_chr
      i = decode_one(string, bytesize, i, byte, char, target_io, plus_to_space) { |byte| yield byte }
    end

    if io_memory
      io.write_string(io_memory.to_slice)
    end
  end

  # URL-encodes *string* and writes the result to an `IO`.
  #
  # The block is called for each ascii character (codepoint less than `0x80`) and
  # determines whether the value is to be encoded. When the return value is falsey,
  # the character is encoded. Non-ASCII characters are always encoded.
  #
  # By default, the space character (`0x20`) is encoded as `%20` and `+` is
  # encoded literally. If *space_to_plus* is `true`, space character is encoded
  # as `+` and `+` is encoded as `%2B`.
  #
  # This method enables some customization, but typical use cases can be implemented
  # by either `.encode_path(string : String) : String`, `.encode_path_segment(string : String) : String` or
  # `.encode_www_form(string : String, *, space_to_plus : Bool = true) : String`.
  def self.encode(string : String, io : IO, space_to_plus : Bool = false, &block) : Nil
    string.each_byte do |byte|
      char = byte.unsafe_chr
      if char == ' ' && space_to_plus
        io << '+'
      elsif char.ascii? && yield(byte) && (!space_to_plus || char != '+')
        io << char
      else
        io << '%'
        io << '0' if byte < 16
        byte.to_s(io, 16, upcase: true)
      end
    end
    io
  end

  # :nodoc:
  def self.decode_one(string, bytesize, i, byte, char, io, plus_to_space = false)
    self.decode_one(string, bytesize, i, byte, char, io, plus_to_space) { false }
  end

  # :nodoc:
  # Unencodes one character. Private API
  def self.decode_one(string, bytesize, i, byte, char, io, plus_to_space = false, &)
    if plus_to_space && char == '+'
      io.write_byte ' '.ord.to_u8
      i += 1
      return i
    end

    if char == '%' && i < bytesize - 2
      i += 1
      first = string.to_unsafe[i]
      first_num = first.unsafe_chr.to_i? 16
      unless first_num
        io.write_byte byte
        return i
      end

      i += 1
      second = string.to_unsafe[i]
      second_num = second.unsafe_chr.to_i? 16
      unless second_num
        io.write_byte byte
        io.write_byte first
        return i
      end

      encoded = (first_num * 16 + second_num).to_u8
      i += 1
      if encoded < 0x80 && yield encoded
        io.write_byte byte
        io.write_byte first
        io.write_byte second
        return i
      end
      io.write_byte encoded
      return i
    end

    io.write_byte byte
    i += 1
    i
  end

  # Checks if there's any chars that actually needs decoding.
  # If not, decoding a string can be done much faster, because
  # it's just the same string.
  private def self.needs_decode?(string : String, *, plus_to_space : Bool) : Bool
    string.includes?('%') || (plus_to_space && string.includes?('+'))
  end
end
