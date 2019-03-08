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
# # => #<URI:0x1003f1e40 @scheme="http", @host="foo.com", @port=nil, @path="/posts", @query="id=30&limit=5", ... >
# uri.scheme # => "http"
# uri.host   # => "foo.com"
# uri.query  # => "id=30&limit=5"
# uri.to_s   # => "http://foo.com/posts?id=30&limit=5#time=1305298413"
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

  # Returns the host part of the URI and unwrap brackets for IPv6 addresses.
  #
  # ```
  # URI.parse("http://[::1]/bar").hostname # => "::1"
  # URI.parse("http://[::1]/bar").host     # => "[::1]"
  # ```
  def hostname
    host.try { |host| host.starts_with?('[') && host.ends_with?(']') ? host[1..-2] : host }
  end

  # Returns the full path of this URI.
  #
  # ```
  # uri = URI.parse "http://foo.com/posts?id=30&limit=5#time=1305298413"
  # uri.full_path # => "/posts?id=30&limit=5"
  # ```
  def full_path
    String.build do |str|
      str << (@path.try { |p| !p.empty? } ? @path : '/')
      if (query = @query) && !query.empty?
        str << '?' << query
      end
    end
  end

  # Returns `true` if URI has a *scheme* specified.
  def absolute?
    @scheme ? true : false
  end

  # Returns `true` if URI does not have a *scheme* specified.
  def relative?
    !absolute?
  end

  def to_s(io : IO) : Nil
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
    unless port.nil? || default_port?
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

  # Returns normalized URI.
  def normalize
    uri = dup
    uri.normalize!
    uri
  end

  # Destructive normalize.
  def normalize!
    @path = remove_dot_segments(path)
  end

  # Parses `raw_url` into an URI. The `raw_url` may be relative or absolute.
  #
  # ```
  # require "uri"
  #
  # uri = URI.parse("http://crystal-lang.org") # => #<URI:0x1068a7e40 @scheme="http", @host="crystal-lang.org", ... >
  # uri.scheme                                 # => "http"
  # uri.host                                   # => "crystal-lang.org"
  # ```
  def self.parse(raw_url : String) : URI
    URI::Parser.new(raw_url).run.uri
  end

  # URL-decode a `String`.
  #
  # If *plus_to_space* is `true`, it replace plus character (`0x2B`) to ' '.
  # e.g. `application/x-www-form-urlencoded` wants this replace.
  #
  # ```
  # URI.unescape("%27Stop%21%27%20said%20Fred")                  # => "'Stop!' said Fred"
  # URI.unescape("%27Stop%21%27+said+Fred", plus_to_space: true) # => "'Stop!' said Fred"
  # ```
  def self.unescape(string : String, plus_to_space = false) : String
    String.build { |io| unescape(string, io, plus_to_space) }
  end

  # URL-decode a `String`.
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

  # URL-decode a `String` and write the result to an `IO`.
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

  # URL-encode a `String`.
  #
  # If *space_to_plus* is `true`, it replace space character (0x20) to `'+'` and `'+'` is
  # encoded to `'%2B'`. e.g. `application/x-www-form-urlencoded` want this replace.
  #
  # ```
  # URI.escape("'Stop!' said Fred")                      # => "%27Stop%21%27%20said%20Fred"
  # URI.escape("'Stop!' said Fred", space_to_plus: true) # => "%27Stop%21%27+said+Fred"
  # ```
  def self.escape(string : String, space_to_plus = false) : String
    String.build { |io| escape(string, io, space_to_plus) }
  end

  # URL-encode a `String`.
  #
  # This method requires block, the block is called with each characters
  # whose code is less than `0x80`. The characters that block returns
  # `true` are not escaped, other characters are escaped.
  #
  # ```
  # # Escape URI path
  # URI.escape("/foo/file?(1).txt") do |byte|
  #   URI.unreserved?(byte) || byte.chr == '/'
  # end
  # # => "/foo/file%3F%281%29.txt"
  # ```
  def self.escape(string : String, space_to_plus = false, &block) : String
    String.build { |io| escape(string, io, space_to_plus) { |byte| yield byte } }
  end

  # URL-encode a `String` and write the result to an `IO`.
  def self.escape(string : String, io : IO, space_to_plus = false)
    self.escape(string, io, space_to_plus) { |byte| URI.unreserved? byte }
  end

  # URL-encode a `String` and write the result to an `IO`.
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

  # Returns whether given byte is reserved character defined in
  # [RFC 3986](https://tools.ietf.org/html/rfc3986).
  #
  # Reserved characters are ':', '/', '?', '#', '[', ']', '@', '!',
  # '$', '&', "'", '(', ')', '*', '+', ',', ';' and '='.
  def self.reserved?(byte) : Bool
    char = byte.unsafe_chr
    '&' <= char <= ',' ||
      {'!', '#', '$', '/', ':', ';', '?', '@', '[', ']', '='}.includes?(char)
  end

  # Returns whether given byte is unreserved character defined in
  # [RFC 3986](https://tools.ietf.org/html/rfc3986).
  #
  # Unreserved characters are alphabet, digit, '_', '.', '-', '~'.
  def self.unreserved?(byte) : Bool
    char = byte.unsafe_chr
    char.ascii_alphanumeric? ||
      {'_', '.', '-', '~'}.includes?(char)
  end

  # Returns the user-information component containing
  # the provided username and password.
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

  # [RFC 3986 6.2.2.3](https://tools.ietf.org/html/rfc3986#section-5.2.4)
  private def remove_dot_segments(path : String?)
    return if path.nil?

    result = [] of String
    while path.size > 0
      # A.  If the input buffer begins with a prefix of "../" or "./",
      #     then remove that prefix from the input buffer; otherwise,
      if path.starts_with?("../")
        path = path[3..-1]
      elsif path.starts_with?("./")
        path = path[2..-1]
        # B.  if the input buffer begins with a prefix of "/./" or "/.",
        #     where "." is a complete path segment, then replace that
        #     prefix with "/" in the input buffer; otherwise,
      elsif path.starts_with?("/./")
        path = "/" + path[3..-1]
      elsif path == "/."
        path = "/" + path[2..-1]
        # C.  if the input buffer begins with a prefix of "/../" or "/..",
        #     where ".." is a complete path segment, then replace that
        #     prefix with "/" in the input buffer and remove the last
        #     segment and its preceding "/" (if any) from the output
        #     buffer; otherwise,
      elsif path.starts_with?("/../")
        path = "/" + path[4..-1]
        result.pop if result.size > 0
      elsif path == "/.."
        path = "/" + path[3..-1]
        result.pop if result.size > 0
        # D.  if the input buffer consists only of "." or "..", then remove
        #     that from the input buffer; otherwise,
      elsif path == ".." || path == "."
        path = ""
        # E.  move the first path segment in the input buffer to the end of
        #     the output buffer, including the initial "/" character (if
        #     any) and any subsequent characters up to, but not including,
        #     the next "/" character or the end of the input buffer.
      else
        slash_search_idx = path[0] == '/' ? 1 : 0
        segment_end_idx = path.index("/", slash_search_idx)
        segment_end_idx ||= path.size
        result << path[0...segment_end_idx]
        path = path[segment_end_idx..-1]
      end
    end

    result.join
  end

  private def userinfo(user, io)
    URI.escape(user, io)
    if password = @password
      io << ':'
      URI.escape(password, io)
    end
  end

  # A map of schemes and their respective default ports, seeded
  # with some well-known schemes sourced from the IANA [Uniform
  # Resource Identifier (URI) Schemes][1] and [Service Name and
  # Transport Protocol Port Number Registry][2] via Mahmoud
  # Hashemi's [scheme_port_map.json][3].
  #
  # [1]: https://www.iana.org/assignments/uri-schemes/uri-schemes.xhtml
  # [2]: https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml
  # [3]: https://gist.github.com/mahmoud/2fe281a8daaff26cfe9c15d2c5bf5c8b
  @@default_ports = {
    "acap"     => 674,
    "afp"      => 548,
    "dict"     => 2628,
    "dns"      => 53,
    "ftp"      => 21,
    "ftps"     => 990,
    "git"      => 9418,
    "gopher"   => 70,
    "http"     => 80,
    "https"    => 443,
    "imap"     => 143,
    "ipp"      => 631,
    "ipps"     => 631,
    "irc"      => 194,
    "ircs"     => 6697,
    "ldap"     => 389,
    "ldaps"    => 636,
    "mms"      => 1755,
    "msrp"     => 2855,
    "mtqp"     => 1038,
    "nfs"      => 111,
    "nntp"     => 119,
    "nntps"    => 563,
    "pop"      => 110,
    "prospero" => 1525,
    "redis"    => 6379,
    "rsync"    => 873,
    "rtsp"     => 554,
    "rtsps"    => 322,
    "rtspu"    => 5005,
    "scp"      => 22,
    "sftp"     => 22,
    "smb"      => 445,
    "snmp"     => 161,
    "ssh"      => 22,
    "svn"      => 3690,
    "telnet"   => 23,
    "ventrilo" => 3784,
    "vnc"      => 5900,
    "wais"     => 210,
    "ws"       => 80,
    "wss"      => 443,
  }

  # Returns the default port for the given *scheme* if known,
  # otherwise returns `nil`.
  #
  # ```
  # URI.default_port "http"  # => 80
  # URI.default_port "ponzi" # => nil
  # ```
  def self.default_port(scheme : String) : Int32?
    @@default_ports[scheme.downcase]?
  end

  # Registers the default port for the given *scheme*.
  #
  # If *port* is `nil`, the existing default port for the
  # *scheme*, if any, will be unregistered.
  #
  # ```
  # URI.set_default_port "ponzi", 9999
  # ```
  def self.set_default_port(scheme : String, port : Int32?) : Nil
    if port
      @@default_ports[scheme.downcase] = port
    else
      @@default_ports.delete scheme.downcase
    end
  end

  # Returns `true` if this URI's *port* is the default port for
  # its *scheme*.
  private def default_port?
    (scheme = @scheme) && (port = @port) && port == URI.default_port(scheme)
  end
end
