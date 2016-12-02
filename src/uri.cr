require "./uri/uri_parser"

# This class represents a URI reference as defined by [RFC 3986: Uniform Resource Identifier
# (URI): Generic Syntax](https://www.ietf.org/rfc/rfc3986.txt).
#
# This class provides constructors for creating URI instances from
# their components or by parsing their string forms and methods for accessing the various
# components of an instance.
#
# Basic example:
#
# ```
# require "uri"
#
# uri = URI.parse "http://foo.com/posts?id=30&limit=5#time=1305298413"
# # => #&lt;URI:0x1003f1e40 @scheme="http", @host="foo.com", @port=nil, @path="/posts", @query="id=30&limit=5", ... >
# uri.scheme
# # => "http"
# uri.host
# # => "foo.com"
# uri.query
# # => "id=30&limit=5"
# uri.to_s
# # => "http://foo.com/posts?id=30&limit=5#time=1305298413"
# ```
class URI
  class Error < Exception
  end

  # Returns the scheme component of the URI.
  #
  # ```
  # URI.parse("http://foo.com").scheme           # => "http"
  # URI.parse("mailto:alice@example.com").scheme # => "mailto"
  # ```
  getter scheme : String?

  # Sets the scheme component of the URI.
  setter scheme : String?

  # Returns the host component of the URI.
  #
  # ```
  # URI.parse("http://foo.com").host # => "foo.com"
  # ```
  getter host : String?

  # Sets the host component of the URI.
  setter host : String?

  # Returns the port component of the URI.
  #
  # ```
  # URI.parse("http://foo.com:5432").port # => 5432
  # ```
  getter port : Int32?

  # Sets the port component of the URI.
  setter port : Int32?

  # Returns the path component of the URI.
  #
  # ```
  # URI.parse("http://foo.com/bar").path # => "/bar"
  # ```
  getter path : String?

  # Sets the path component of the URI.
  setter path : String?

  # Returns the query component of the URI.
  #
  # ```
  # URI.parse("http://foo.com/bar?q=1").query # => "q=1"
  # ```
  getter query : String?

  # Sets the query component of the URI.
  setter query : String?

  # Returns the user component of the URI.
  #
  # ```
  # URI.parse("http://admin:password@foo.com").user # => "admin"
  # ```
  getter user : String?

  # Sets the user component of the URI.
  setter user : String?

  # Returns the password component of the URI.
  #
  # ```
  # URI.parse("http://admin:password@foo.com").password # => "password"
  # ```
  getter password : String?

  # Sets the password component of the URI.
  setter password : String?

  # Returns the fragment component of the URI.
  #
  # ```
  # URI.parse("http://foo.com/bar#section1").fragment # => "section1"
  # ```
  getter fragment : String?

  # Sets the fragment component of the URI.
  setter fragment : String?

  # Returns the opaque component of the URI.
  #
  # ```
  # URI.parse("mailto:alice@example.com").opaque # => "alice@example.com"
  # ```
  getter opaque : String?

  # Sets the opaque component of the URI.
  setter opaque : String?

  def_equals_and_hash scheme, host, port, path, query, user, password, fragment, opaque

  def initialize(@scheme = nil, @host = nil, @port = nil, @path = nil, @query = nil, @user = nil, @password = nil, @fragment = nil, @opaque = nil)
  end

  # Returns the full path of this URI.
  #
  # ```
  # uri = URI.parse "http://foo.com/posts?id=30&limit=5#time=1305298413"
  # uri.full_path # => "/posts?id=30&limit=5"
  # ```
  def full_path
    String.build do |str|
      str << (@path.try { |p| !p.empty? } ? @path : "/")
      str << "?" << @query if @query
    end
  end

  def to_s(io : IO)
    if scheme
      io << scheme
      io << ':'
      io << "//" unless opaque
    end
    if opaque
      io << opaque
      return
    end
    if user = @user
      userinfo(user, io)
      io << '@'
    end
    if host
      io << host
    end
    if port && !((scheme == "http" && port == 80) || (scheme == "https" && port == 443))
      io << ':'
      io << port
    end
    if path
      io << path
    end
    if query
      io << '?'
      io << query
    end
    if fragment
      io << '#'
      io << fragment
    end
  end

  # Parses `raw_url` into an URI. The `raw_url` may be relative or absolute.
  #
  # ```
  # require 'uri'
  #
  # uri = URI.parse("http://crystal-lang.org")
  # # => #<URI:0x1068a7e40 @scheme="http", @host="crystal-lang.org", ... >
  # uri.scheme
  # # => "http"
  # uri.host
  # # => "crystal-lang.org"
  # ```
  def self.parse(raw_url : String) : URI
    URI::Parser.new(raw_url).run.uri
  end

  # URL-decode a string.
  #
  # If *plus_to_space* is true, it replace plus character (0x2B) to ' '.
  # e.g. `application/x-www-form-urlencoded` wants this replace.
  #
  #     URI.unescape("%27Stop%21%27%20said%20Fred")                  #=> "'Stop!' said Fred"
  #     URI.unescape("%27Stop%21%27+said+Fred", plus_to_space: true) #=> "'Stop!' said Fred"
  def self.unescape(string : String, plus_to_space = false) : String
    String.build { |io| unescape(string, io, plus_to_space) }
  end

  # URL-decode a string.
  #
  # This method requires block, the block is called with each bytes
  # whose is less than `0x80`. The bytes that block returns `true`
  # are not unescaped, other characters are unescaped.
  def self.unescape(string : String, plus_to_space = false, &block) : String
    String.build { |io| unescape(string, io, plus_to_space) { |byte| yield byte } }
  end

  # URL-decode a string and write the result to an `IO`.
  def self.unescape(string : String, io : IO, plus_to_space = false)
    self.unescape(string, io, plus_to_space) { false }
  end

  # URL-decode a string and write the result to an `IO`.
  #
  # This method requires block.
  def self.unescape(string : String, io : IO, plus_to_space = false, &block)
    i = 0
    bytesize = string.bytesize
    while i < bytesize
      byte = string.unsafe_byte_at(i)
      char = byte.unsafe_chr
      i = unescape_one(string, bytesize, i, byte, char, io, plus_to_space) { |byte| yield byte }
    end
    io
  end

  # URL-encode a string.
  #
  # If *space_to_plus* is true, it replace space character (0x20) to '+' and '+' is
  # encoded to '%2B'. e.g. `application/x-www-form-urlencoded` want this replace.
  #
  #     URI.escape("'Stop!' said Fred")                      #=> "%27Stop%21%27%20said%20Fred"
  #     URI.escape("'Stop!' said Fred", space_to_plus: true) #=> "%27Stop%21%27+said+Fred"
  def self.escape(string : String, space_to_plus = false) : String
    String.build { |io| escape(string, io, space_to_plus) }
  end

  # URL-encode a string.
  #
  # This method requires block, the block is called with each characters
  # whose code is less than `0x80`. The characters that block returns
  # `true` are not escaped, other characters are escaped.
  #
  #     # Escape URI path
  #     URI.escape("/foo/file?(1).txt") do |byte|
  #       URI.unreserved?(byte) || byte.chr == '/'
  #     end
  #     #=> "/foo/file%3F%281%29.txt"
  def self.escape(string : String, space_to_plus = false, &block) : String
    String.build { |io| escape(string, io, space_to_plus) { |byte| yield byte } }
  end

  # URL-encode a string and write the result to an `IO`.
  def self.escape(string : String, io : IO, space_to_plus = false)
    self.escape(string, io, space_to_plus) { |byte| URI.unreserved? byte }
  end

  # URL-encode a string and write the result to an `IO`.
  #
  # This method requires block.
  def self.escape(string : String, io : IO, space_to_plus = false, &block)
    string.each_byte do |byte|
      char = byte.unsafe_chr
      if char == ' ' && space_to_plus
        io.write_byte '+'.ord.to_u8
      elsif char.ascii? && yield(byte) && (!space_to_plus || char != '+')
        io.write_byte byte
      else
        io.write_byte '%'.ord.to_u8
        io.write_byte '0'.ord.to_u8 if byte < 16
        byte.to_s(16, io, upcase: true)
      end
    end
    io
  end

  # Returns whether given byte is reserved character defined in RFC 3986.
  #
  # Reserved characters are ':', '/', '?', '#', '[', ']', '@', '!',
  # '$', '&', "'", '(', ')', '*', '+', ',', ';' and '='.
  def self.reserved?(byte) : Bool
    char = byte.unsafe_chr
    '&' <= char <= ',' ||
      {'!', '#', '$', '/', ':', ';', '?', '@', '[', ']', '='}.includes?(char)
  end

  # Returns whether given byte is unreserved character defined in RFC 3986.
  #
  # Unreserved characters are alphabet, digit, '_', '.', '-', '~'.
  def self.unreserved?(byte) : Bool
    char = byte.unsafe_chr
    char.ascii_alphanumeric? ||
      {'_', '.', '-', '~'}.includes?(char)
  end

  # Returns the user-information component containing the provided username and password.
  #
  # ```
  # uri = URI.parse "http://admin:password@foo.com"
  # uri.userinfo # => "admin:password"
  # ```
  def userinfo
    if user = @user
      String.build { |io| userinfo(user, io) }
    end
  end

  # :nodoc:
  def self.unescape_one(string, bytesize, i, byte, char, io, plus_to_space = false)
    self.unescape_one(string, bytesize, i, byte, char, io, plus_to_space) { false }
  end

  # :nodoc:
  # Unescapes one character. Private API
  def self.unescape_one(string, bytesize, i, byte, char, io, plus_to_space = false)
    if plus_to_space && char == '+'
      io.write_byte ' '.ord.to_u8
      i += 1
      return i
    end

    if char == '%' && i < bytesize - 2
      i += 1
      first = string.unsafe_byte_at(i)
      first_num = first.unsafe_chr.to_i? 16
      unless first_num
        io.write_byte byte
        return i
      end

      i += 1
      second = string.unsafe_byte_at(i)
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

  private def userinfo(user, io)
    URI.escape(user, io)
    if password = @password
      io << ':'
      URI.escape(password, io)
    end
  end
end
