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
  # URI defined in RFC3986
  RFC3986_URI          = /\A(?<URI>(?<scheme>[A-Za-z][+\-.0-9A-Za-z]*):(?<hier_part>\/\/(?<authority>(?:(?<userinfo>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-;=A-Z_a-z~])*)@)?(?<host>(?<IP_literal>\[(?:(?<IPv6address>(?:[0-9a-fA-F]{1,4}:){6}(?<ls32>[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}|(?<IPv4address>(?<dec_octet>[1-9]\d|1\d{2}|2[0-4]\d|25[0-5]|\d)\.\g<dec_octet>\.\g<dec_octet>\.\g<dec_octet>))|::(?:[0-9a-fA-F]{1,4}:){5}\g<ls32>|[0-9a-fA-F]{1,4}?::(?:[0-9a-fA-F]{1,4}:){4}\g<ls32>|(?:(?:[0-9a-fA-F]{1,4}:)?[0-9a-fA-F]{1,4})?::(?:[0-9a-fA-F]{1,4}:){3}\g<ls32>|(?:(?:[0-9a-fA-F]{1,4}:){,2}[0-9a-fA-F]{1,4})?::(?:[0-9a-fA-F]{1,4}:){2}\g<ls32>|(?:(?:[0-9a-fA-F]{1,4}:){,3}[0-9a-fA-F]{1,4})?::[0-9a-fA-F]{1,4}:\g<ls32>|(?:(?:[0-9a-fA-F]{1,4}:){,4}[0-9a-fA-F]{1,4})?::\g<ls32>|(?:(?:[0-9a-fA-F]{1,4}:){,5}[0-9a-fA-F]{1,4})?::[0-9a-fA-F]{1,4}|(?:(?:[0-9a-fA-F]{1,4}:){,6}[0-9a-fA-F]{1,4})?::)|(?<IPvFuture>v[0-9a-fA-F]+\.[!$&-.0-;=A-Z_a-z~]+))\])|\g<IPv4address>|(?<reg_name>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-9;=A-Z_a-z~])+))?(?::(?<port>\d*))?)(?<path_abempty>(?:\/(?<segment>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-;=@-Z_a-z~])*))*)|(?<path_absolute>\/(?:(?<segment_nz>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-;=@-Z_a-z~])+)(?:\/\g<segment>)*)?)|(?<path_rootless>\g<segment_nz>(?:\/\g<segment>)*)|(?<path_empty>))(?:\?(?<query>[^#]*))?(?:\#(?<fragment>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-;=@-Z_a-z~\/?])*))?)\z/
  RFC3986_relative_ref = /\A(?<relative_ref>(?<relative_part>\/\/(?<authority>(?:(?<userinfo>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-;=A-Z_a-z~])*)@)?(?<host>(?<IP_literal>\[(?<IPv6address>(?:[0-9a-fA-F]{1,4}:){6}(?<ls32>[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}|(?<IPv4address>(?<dec_octet>[1-9]\d|1\d{2}|2[0-4]\d|25[0-5]|\d)\.\g<dec_octet>\.\g<dec_octet>\.\g<dec_octet>))|::(?:[0-9a-fA-F]{1,4}:){5}\g<ls32>|[0-9a-fA-F]{1,4}?::(?:[0-9a-fA-F]{1,4}:){4}\g<ls32>|(?:(?:[0-9a-fA-F]{1,4}:){,1}[0-9a-fA-F]{1,4})?::(?:[0-9a-fA-F]{1,4}:){3}\g<ls32>|(?:(?:[0-9a-fA-F]{1,4}:){,2}[0-9a-fA-F]{1,4})?::(?:[0-9a-fA-F]{1,4}:){2}\g<ls32>|(?:(?:[0-9a-fA-F]{1,4}:){,3}[0-9a-fA-F]{1,4})?::[0-9a-fA-F]{1,4}:\g<ls32>|(?:(?:[0-9a-fA-F]{1,4}:){,4}[0-9a-fA-F]{1,4})?::\g<ls32>|(?:(?:[0-9a-fA-F]{1,4}:){,5}[0-9a-fA-F]{1,4})?::[0-9a-fA-F]{1,4}|(?:(?:[0-9a-fA-F]{1,4}:){,6}[0-9a-fA-F]{1,4})?::)|(?<IPvFuture>v[0-9a-fA-F]+\.[!$&-.0-;=A-Z_a-z~]+)\])|\g<IPv4address>|(?<reg_name>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-9;=A-Z_a-z~])+))?(?::(?<port>\d*))?)(?<path_abempty>(?:\/(?<segment>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-;=@-Z_a-z~])*))*)|(?<path_absolute>\/(?:(?<segment_nz>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-;=@-Z_a-z~])+)(?:\/\g<segment>)*)?)|(?<path_noscheme>(?<segment_nz_nc>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-9;=@-Z_a-z~])+)(?:\/\g<segment>)*)|(?<path_empty>))(?:\?(?<query>[^#]*))?(?:\#(?<fragment>(?:%[0-9a-fA-F][0-9a-fA-F]|[!$&-.0-;=@-Z_a-z~\/?])*))?)\z/

  # Returns the scheme component of the URI.
  #
  # ```
  # URI.parse("http://foo.com").scheme           # => "http"
  # URI.parse("mailto:alice@example.com").scheme # => "mailto"
  # ```
  getter scheme

  # Sets the scheme component of the URI.
  setter scheme

  # Returns the host component of the URI.
  #
  # ```
  # URI.parse("http://foo.com").host # => "foo.com"
  # ```
  getter host

  # Sets the host component of the URI.
  setter host

  # Returns the port component of the URI.
  #
  # ```
  # URI.parse("http://foo.com:5432").port # => 5432
  # ```
  getter port

  # Sets the port component of the URI.
  setter port

  # Returns the path component of the URI.
  #
  # ```
  # URI.parse("http://foo.com/bar").path # => "/bar"
  # ```
  getter path

  # Sets the path component of the URI.
  setter path

  # Returns the query component of the URI.
  #
  # ```
  # URI.parse("http://foo.com/bar?q=1").query # => "q=1"
  # ```
  getter query

  # Sets the query component of the URI.
  setter query

  # Returns the user component of the URI.
  #
  # ```
  # URI.parse("http://admin:password@foo.com").user # => "admin"
  # ```
  getter user

  # Sets the user component of the URI.
  setter user

  # Returns the password component of the URI.
  #
  # ```
  # URI.parse("http://admin:password@foo.com").password # => "password"
  # ```
  getter password

  # Sets the password component of the URI.
  setter password

  # Returns the fragment component of the URI.
  #
  # ```
  # URI.parse("http://foo.com/bar#section1").fragment # => "section1"
  # ```
  getter fragment

  # Sets the fragment component of the URI.
  setter fragment

  # Returns the opaque component of the URI.
  #
  # ```
  # URI.parse("mailto:alice@example.com").opaque # => "alice@example.com"
  # ```
  getter opaque

  # Sets the opaque component of the URI.
  setter opaque

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
  def self.parse(raw_url : String)
    if m = RFC3986_URI.match(raw_url)
      query = m["query"]?
      scheme = m["scheme"]?
      opaque = m["path_rootless"]?
      if opaque
        opaque = opaque + "?#{query}" if query
      else
        userinfo = m["userinfo"]?
        host = m["host"]?
        port = m["port"]?.try(&.to_i)
        path = m["path_abempty"]? || m["path_absolute"]? || m["path_empty"]?
        fragment = m["fragment"]?
      end
    elsif m = RFC3986_relative_ref.match(raw_url)
      userinfo = m["userinfo"]?
      host = m["host"]?
      port = m["port"]?.try(&.to_i)
      path = m["path_abempty"]? || m["path_absolute"]? || m["path_noscheme"]? || m["path_empty"]?
      query = m["query"]?
      fragment = m["fragment"]?
    else
      raise "bad URI(is not URI?): #{raw_url}"
    end

    if userinfo
      split = userinfo.split(":")
      user = URI.unescape split[0]
      if password = split[1]?
        password = URI.unescape split[1]
      end
    else
      user = password = nil
    end

    new scheme: scheme, host: host, port: port, path: path, query: query, user: user, password: password, fragment: fragment, opaque: opaque
  end

  # URL-decode a string.
  #
  #     URI.unescape("%27Stop%21%27+said+Fred") #=> "'Stop!' said Fred"
  def self.unescape(string : String)
    String.build { |io| unescape(string, io) }
  end

  # URL-decode a string and write the result to an `IO`.
  def self.unescape(string : String, io : IO)
    i = 0
    bytesize = string.bytesize
    while i < bytesize
      byte = string.unsafe_byte_at(i)
      char = byte.chr
      i = unescape_one string, bytesize, i, byte, char, io
    end
    io
  end

  # URL-encode a string.
  #
  #     URI.escape("'Stop!' said Fred") #=> "%27Stop%21%27+said+Fred"
  def self.escape(string : String)
    String.build { |io| escape(string, io) }
  end

  # URL-encode a string and write the result to an `IO`.
  def self.escape(string : String, io : IO)
    string.each_char do |char|
      if char.alphanumeric? || char == '_' || char == '.' || char == '-'
        io.write_byte char.ord.to_u8
      else
        char.each_byte do |byte|
          io.write_byte '%'.ord.to_u8
          io.write_byte '0'.ord.to_u8 if byte < 16
          byte.to_s(16, io, upcase: true)
        end
      end
    end
    io
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
  # Unescapes one character. Private API
  def self.unescape_one(string, bytesize, i, byte, char, io)
    if char == '+'
      io.write_byte ' '.ord.to_u8
      i += 1
      return i
    end

    if char == '%' && i < bytesize - 2
      i += 1
      first = string.unsafe_byte_at(i)
      first_num = first.chr.to_i 16, or_else: nil
      unless first_num
        io.write_byte byte
        return i
      end

      i += 1
      second = string.unsafe_byte_at(i)
      second_num = second.chr.to_i 16, or_else: nil
      unless second_num
        io.write_byte byte
        io.write_byte first
        return i
      end

      io.write_byte (first_num * 16 + second_num).to_u8
      i += 1
      return i
    end

    io.write_byte byte
    i += 1
    i
  end

  private def userinfo(user, io)
    escape(user, io)
    if password = @password
      io << ':'
      escape(password, io)
    end
  end

  private def escape(str, io)
    str.each_byte do |byte|
      case byte
      when ':', '@', '/'
        io << '%'
        byte.to_s(16, io, upcase: true)
      else
        io.write_byte byte
      end
    end
  end
end
