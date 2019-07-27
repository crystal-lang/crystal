require "./uri/uri_parser"
require "./uri/encoding"

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
#
# # URL Encoding
#
# This class provides a number of methods for encoding and decoding strings using
# URL Encoding (also known as Percent Encoding) as defined in [RFC 3986](https://www.ietf.org/rfc/rfc3986.txt)
# as well as [`x-www-form-urlencoded`](https://url.spec.whatwg.org/#urlencoded-serializing).
#
# Each method has two variants, one returns a string, the other writes directly
# to an IO.
#
# * `.decode(string : String, *, plus_to_space : Bool = false) : String`: Decodes a URL-encoded string.
# * `.decode(string : String, io : IO, *, plus_to_space : Bool = false) : Nil`: Decodes a URL-encoded string to an IO.
# * `.encode(string : String, *, space_to_plus : Bool = false) : String`: URL-encodes a string.
# * `.encode(string : String, io : IO, *, space_to_plus : Bool = false) : Nil`: URL-encodes a string to an IO.
# * `.decode_www_form(string : String, *, plus_to_space : Bool = true) : String`: Decodes an `x-www-form-urlencoded` string component.
# * `.decode_www_form(string : String, io : IO, *, plus_to_space : Bool = true) : Nil`: Decodes an `x-www-form-urlencoded` string component to an IO.
# * `.encode_www_form(string : String, *, space_to_plus : Bool = true) : String`: Encodes a string as a `x-www-form-urlencoded` component.
# * `.encode_www_form(string : String, io : IO, *, space_to_plus : Bool = true) : Nil`: Encodes a string as a `x-www-form-urlencoded` component to an IO.
#
# The main difference is that `.encode_www_form` encodes reserved characters
# (see `.reserved?`), while `.encode` does not. The decode methods are
# identical except for the handling of `+` characters.
#
# NOTE: `HTTP::Params` provides a higher-level API for handling `x-www-form-urlencoded`
# serialized data.
class URI
  class Error < Exception
  end

  # Returns the scheme component of the URI.
  #
  # ```
  # require "uri"
  #
  # URI.parse("http://foo.com").scheme           # => "http"
  # URI.parse("mailto:alice@example.com").scheme # => "mailto"
  # ```
  getter scheme : String?

  # Sets the scheme component of the URI.
  setter scheme : String?

  # Returns the host component of the URI.
  #
  # ```
  # require "uri"
  #
  # URI.parse("http://foo.com").host # => "foo.com"
  # ```
  getter host : String?

  # Sets the host component of the URI.
  setter host : String?

  # Returns the port component of the URI.
  #
  # ```
  # require "uri"
  #
  # URI.parse("http://foo.com:5432").port # => 5432
  # ```
  getter port : Int32?

  # Sets the port component of the URI.
  setter port : Int32?

  # Returns the path component of the URI.
  #
  # ```
  # require "uri"
  #
  # URI.parse("http://foo.com/bar").path # => "/bar"
  # ```
  getter path : String

  # Sets the path component of the URI.
  setter path : String

  # Returns the query component of the URI.
  #
  # ```
  # require "uri"
  #
  # URI.parse("http://foo.com/bar?q=1").query # => "q=1"
  # ```
  getter query : String?

  # Sets the query component of the URI.
  setter query : String?

  # Returns the user component of the URI.
  #
  # ```
  # require "uri"
  #
  # URI.parse("http://admin:password@foo.com").user # => "admin"
  # ```
  getter user : String?

  # Sets the user component of the URI.
  setter user : String?

  # Returns the password component of the URI.
  #
  # ```
  # require "uri"
  #
  # URI.parse("http://admin:password@foo.com").password # => "password"
  # ```
  getter password : String?

  # Sets the password component of the URI.
  setter password : String?

  # Returns the fragment component of the URI.
  #
  # ```
  # require "uri"
  #
  # URI.parse("http://foo.com/bar#section1").fragment # => "section1"
  # ```
  getter fragment : String?

  # Sets the fragment component of the URI.
  setter fragment : String?

  def_equals_and_hash scheme, host, port, path, query, user, password, fragment

  def initialize(@scheme = nil, @host = nil, @port = nil, @path = "", @query = nil, @user = nil, @password = nil, @fragment = nil)
  end

  # Returns the host part of the URI and unwrap brackets for IPv6 addresses.
  #
  # ```
  # require "uri"
  #
  # URI.parse("http://[::1]/bar").hostname # => "::1"
  # URI.parse("http://[::1]/bar").host     # => "[::1]"
  # ```
  def hostname
    host.try { |host| host.starts_with?('[') && host.ends_with?(']') ? host[1..-2] : host }
  end

  # Returns the full path of this URI.
  #
  # ```
  # require "uri"
  #
  # uri = URI.parse "http://foo.com/posts?id=30&limit=5#time=1305298413"
  # uri.full_path # => "/posts?id=30&limit=5"
  # ```
  def full_path : String
    String.build do |str|
      str << (@path.empty? ? '/' : @path)
      if (query = @query) && !query.empty?
        str << '?' << query
      end
    end
  end

  # Returns `true` if URI has a *scheme* specified.
  def absolute? : Bool
    @scheme ? true : false
  end

  # Returns `true` if URI does not have a *scheme* specified.
  def relative? : Bool
    !absolute?
  end

  # Returns `true` if this URI is opaque.
  #
  # A URI is considered opaque if it has a `scheme` but no hierachical part,
  # i.e. no `host` and the first character of `path` is not a slash (`/`).
  def opaque? : Bool
    !@scheme.nil? && @host.nil? && !@path.starts_with?('/')
  end

  def to_s(io : IO) : Nil
    if scheme
      io << scheme
      io << ':'
    end

    authority = @user || @host || @port
    io << "//" if authority
    if user = @user
      userinfo(user, io)
      io << '@'
    end
    if host = @host
      URI.encode(host, io)
    end
    if port = @port
      io << ':' << port
    end

    if authority
      if !@path.empty? && !@path.starts_with?('/')
        io << '/'
      end
    elsif @path.starts_with?("//")
      io << "/."
    end
    io << @path

    if query
      io << '?'
      io << query
    end
    if fragment
      io << '#'
      io << fragment
    end
  end

  # Returns a normalized copy of this URI.
  #
  # See `#normalize!` for details.
  def normalize : URI
    dup.normalize!
  end

  # Normalizes this URI instance.
  #
  # The following normalizations are applied to the individual components (if available):
  #
  # * `scheme` is lowercased.
  # * `host` is lowercased.
  # * `port` is removed if it is the `.default_port?` of the scheme.
  # * `path` is resolved to a minimal, semantical equivalent representation removing
  #    dot segments `/.` and `/..`.
  #
  # ```
  # uri = URI.parse("HTTP://example.COM:80/./foo/../bar/")
  # uri.normalize!
  # uri # => "http://example.com/bar/"
  # ```
  def normalize! : URI
    @scheme = @scheme.try &.downcase
    @host = @host.try &.downcase
    @port = nil if default_port?
    @path = remove_dot_segments(path)

    self
  end

  # Parses the given *raw_url* into an URI. The *raw_url* may be relative or absolute.
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

  # Returns the user-information component containing
  # the provided username and password.
  #
  # ```
  # require "uri"
  #
  # uri = URI.parse "http://admin:password@foo.com"
  # uri.userinfo # => "admin:password"
  # ```
  #
  # The return value is URL encoded (see `#encode_www_form`).
  def userinfo
    if user = @user
      String.build { |io| userinfo(user, io) }
    end
  end

  private def userinfo(user, io)
    URI.encode_www_form(user, io)
    if password = @password
      io << ':'
      URI.encode_www_form(password, io)
    end
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

  # [RFC 3986 6.2.2.3](https://tools.ietf.org/html/rfc3986#section-5.2.4)
  private def remove_dot_segments(path : String)
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
    first = result.first?
    if first && !first.starts_with?('/') && first.includes?(':')
      result.unshift "./"
    end

    result.join
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
  # require "uri"
  #
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
  # require "uri"
  #
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
