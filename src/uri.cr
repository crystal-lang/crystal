require "cgi"

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
  RFC3986_URI = /\A(?<URI>(?<scheme>[A-Za-z][+\-.0-9A-Za-z]*):(?<hier_part>\/\/(?<authority>(?:(?<userinfo>(?:%\h\h|[!$&-.0-;=A-Z_a-z~])*)@)?(?<host>(?<IP_literal>\[(?:(?<IPv6address>(?:\h{1,4}:){6}(?<ls32>\h{1,4}:\h{1,4}|(?<IPv4address>(?<dec_octet>[1-9]\d|1\d{2}|2[0-4]\d|25[0-5]|\d)\.\g<dec_octet>\.\g<dec_octet>\.\g<dec_octet>))|::(?:\h{1,4}:){5}\g<ls32>|\h{1,4}?::(?:\h{1,4}:){4}\g<ls32>|(?:(?:\h{1,4}:)?\h{1,4})?::(?:\h{1,4}:){3}\g<ls32>|(?:(?:\h{1,4}:){,2}\h{1,4})?::(?:\h{1,4}:){2}\g<ls32>|(?:(?:\h{1,4}:){,3}\h{1,4})?::\h{1,4}:\g<ls32>|(?:(?:\h{1,4}:){,4}\h{1,4})?::\g<ls32>|(?:(?:\h{1,4}:){,5}\h{1,4})?::\h{1,4}|(?:(?:\h{1,4}:){,6}\h{1,4})?::)|(?<IPvFuture>v\h+\.[!$&-.0-;=A-Z_a-z~]+))\])|\g<IPv4address>|(?<reg_name>(?:%\h\h|[!$&-.0-9;=A-Z_a-z~])+))?(?::(?<port>\d*))?)(?<path_abempty>(?:\/(?<segment>(?:%\h\h|[!$&-.0-;=@-Z_a-z~])*))*)|(?<path_absolute>\/(?:(?<segment_nz>(?:%\h\h|[!$&-.0-;=@-Z_a-z~])+)(?:\/\g<segment>)*)?)|(?<path_rootless>\g<segment_nz>(?:\/\g<segment>)*)|(?<path_empty>))(?:\?(?<query>[^#]*))?(?:\#(?<fragment>(?:%\h\h|[!$&-.0-;=@-Z_a-z~\/?])*))?)\z/
  RFC3986_relative_ref = /\A(?<relative_ref>(?<relative_part>\/\/(?<authority>(?:(?<userinfo>(?:%\h\h|[!$&-.0-;=A-Z_a-z~])*)@)?(?<host>(?<IP_literal>\[(?<IPv6address>(?:\h{1,4}:){6}(?<ls32>\h{1,4}:\h{1,4}|(?<IPv4address>(?<dec_octet>[1-9]\d|1\d{2}|2[0-4]\d|25[0-5]|\d)\.\g<dec_octet>\.\g<dec_octet>\.\g<dec_octet>))|::(?:\h{1,4}:){5}\g<ls32>|\h{1,4}?::(?:\h{1,4}:){4}\g<ls32>|(?:(?:\h{1,4}:){,1}\h{1,4})?::(?:\h{1,4}:){3}\g<ls32>|(?:(?:\h{1,4}:){,2}\h{1,4})?::(?:\h{1,4}:){2}\g<ls32>|(?:(?:\h{1,4}:){,3}\h{1,4})?::\h{1,4}:\g<ls32>|(?:(?:\h{1,4}:){,4}\h{1,4})?::\g<ls32>|(?:(?:\h{1,4}:){,5}\h{1,4})?::\h{1,4}|(?:(?:\h{1,4}:){,6}\h{1,4})?::)|(?<IPvFuture>v\h+\.[!$&-.0-;=A-Z_a-z~]+)\])|\g<IPv4address>|(?<reg_name>(?:%\h\h|[!$&-.0-9;=A-Z_a-z~])+))?(?::(?<port>\d*))?)(?<path_abempty>(?:\/(?<segment>(?:%\h\h|[!$&-.0-;=@-Z_a-z~])*))*)|(?<path_absolute>\/(?:(?<segment_nz>(?:%\h\h|[!$&-.0-;=@-Z_a-z~])+)(?:\/\g<segment>)*)?)|(?<path_noscheme>(?<segment_nz_nc>(?:%\h\h|[!$&-.0-9;=@-Z_a-z~])+)(?:\/\g<segment>)*)|(?<path_empty>))(?:\?(?<query>[^#]*))?(?:\#(?<fragment>(?:%\h\h|[!$&-.0-;=@-Z_a-z~\/?])*))?)\z/

  property scheme
  property host
  property port
  property path
  property query
  property user
  property password
  property fragment
  property opaque

  def initialize(@scheme = nil, @host = nil, @port = nil, @path = nil, @query = nil, @user = nil, @password = nil, userinfo = nil, @fragment = nil, @opaque = nil)
    self.userinfo = userinfo if userinfo
  end

  # Returns the full path of this URI.
  #
  # ```
  # uri = URI.parse "http://foo.com/posts?id=30&limit=5#time=1305298413"
  # uri.full_path # => "/posts?id=30&limit=5"
  # ```
  def full_path
    String.build do |str|
      str << (@path.try {|p| !p.empty?} ? @path : "/")
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
    if ui = userinfo
      io << ui
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

    new scheme: scheme, host: host, port: port, path: path, query: query, userinfo: userinfo, fragment: fragment, opaque: opaque
  end

  # Sets the user-information.
  #
  # ```
  # uri = URI.parse "http://admin:password@foo.com"
  # uri.userinfo = "user:password"
  # uri.to_s
  # # => "http://user:password@foo.com"
  # ```
  def userinfo=(ui)
    split = ui.split(":")
    self.user = split[0]
    self.password = split[1]?
  end

  # Returns the user-information component containing the provided username and password.
  #
  # ```
  # uri = URI.parse "http://admin:password@foo.com"
  # uri.userinfo # => "admin:password"
  # ```
  def userinfo
    if user && password
      {user, password}.map{|s| CGI.escape(s.not_nil!)}.join(":")
    elsif user
      CGI.escape(user.not_nil!)
    end
  end
end
