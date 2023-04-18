require "./common"

module HTTP
  # Represents a cookie with all its attributes. Provides convenient access and modification of them.
  #
  # NOTE: To use `Cookie`, you must explicitly import it with `require "http/cookie"`
  class Cookie
    # Possible values for the `SameSite` cookie as described in the [Same-site Cookies Draft](https://tools.ietf.org/html/draft-west-first-party-cookies-07#section-4.1.1).
    enum SameSite
      # The browser will send cookies with both cross-site requests and same-site requests.
      #
      # The `None` directive requires the `secure` attribute to be `true` to mitigate risks associated with cross-site access.
      None
      # Prevents the cookie from being sent by the browser in all cross-site browsing contexts.
      Strict
      # Allows the cookie to be sent by the browser during top-level navigations that use a [safe](https://tools.ietf.org/html/rfc7231#section-4.2.1) HTTP method.
      Lax
    end

    getter name : String
    getter value : String
    property path : String?
    property expires : Time?
    property domain : String?
    property http_only : Bool
    property samesite : SameSite?
    property extension : String?
    property max_age : Time::Span?
    getter creation_time : Time

    @secure : Bool?

    def_equals_and_hash name, value, path, expires, domain, secure, http_only, samesite, extension

    # Creates a new `Cookie` instance.
    #
    # Raises `IO::Error` if *name* or *value* are invalid as per [RFC 6265 §4.1.1](https://tools.ietf.org/html/rfc6265#section-4.1.1).
    # Raises `ArgumentError` if *name* has a security prefix but the requirements are not met as per [RFC 6265 bis §4.1.3](https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-07#section-4.1.3).
    # Alternatively, if *name* has a security prefix, and the related properties are `nil`, the prefix will automatically be applied to the cookie.
    def initialize(name : String, value : String, @path : String? = nil,
                   @expires : Time? = nil, @domain : String? = nil,
                   @secure : Bool? = nil, @http_only : Bool = false,
                   @samesite : SameSite? = nil, @extension : String? = nil,
                   @max_age : Time::Span? = nil, @creation_time = Time.utc)
      validate_name(name)
      @name = name
      validate_value(value)
      @value = value
      raise IO::Error.new("Invalid max_age") if @max_age.try { |max_age| max_age < Time::Span.zero }

      self.check_prefix
      self.validate!
    end

    # Returns `true` if this cookie has the *Secure* flag.
    def secure : Bool
      !!@secure
    end

    def secure=(@secure : Bool) : Bool
    end

    # Sets the name of this cookie.
    #
    # Raises `IO::Error` if the value is invalid as per [RFC 6265 §4.1.1](https://tools.ietf.org/html/rfc6265#section-4.1.1).
    def name=(name : String)
      validate_name(name)
      @name = name

      self.check_prefix
    end

    private def validate_name(name)
      raise IO::Error.new("Invalid cookie name") if name.empty?
      name.each_byte do |byte|
        # valid characters for cookie-name per https://tools.ietf.org/html/rfc6265#section-4.1.1
        # and https://tools.ietf.org/html/rfc2616#section-2.2
        # "!#$%&'*+-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ^_`abcdefghijklmnopqrstuvwxyz|~"
        if !byte.in?(0x21...0x7f) ||                 # Non-printable ASCII character
           byte.in?(0x22, 0x28, 0x29, 0x2c, 0x2f) || # '"', '(', ')', ',', '/'
           byte.in?(0x3a..0x40) ||                   # ':', ';', '<', '=', '>', '?', '@'
           byte.in?(0x5b..0x5d) ||                   # '[', '\\', ']'
           byte.in?(0x7b, 0x7d)                      # '{', '}'
          raise IO::Error.new("Invalid cookie name")
        end
      end
    end

    # Sets the value of this cookie.
    #
    # Raises `IO::Error` if the value is invalid as per [RFC 6265 §4.1.1](https://tools.ietf.org/html/rfc6265#section-4.1.1).
    def value=(value : String)
      validate_value(value)
      @value = value
    end

    private def validate_value(value)
      value.each_byte do |byte|
        # valid characters for cookie-value per https://tools.ietf.org/html/rfc6265#section-4.1.1
        # all printable ASCII characters except ' ', ',', '"', ';' and '\\'
        if !byte.in?(0x21...0x7f) || byte.in?(0x22, 0x2c, 0x3b, 0x5c)
          raise IO::Error.new("Invalid cookie value")
        end
      end
    end

    def to_set_cookie_header : String
      path = @path
      expires = @expires
      max_age = @max_age
      domain = @domain
      samesite = @samesite
      String.build do |header|
        to_cookie_header(header)
        header << "; domain=#{domain}" if domain
        header << "; path=#{path}" if path
        header << "; expires=#{HTTP.format_time(expires)}" if expires
        header << "; max-age=#{max_age.to_i}" if max_age
        header << "; Secure" if @secure
        header << "; HttpOnly" if @http_only
        header << "; SameSite=#{samesite}" if samesite
        header << "; #{@extension}" if @extension
      end
    end

    def to_cookie_header : String
      String.build(@name.bytesize + @value.bytesize + 1) do |io|
        to_cookie_header(io)
      end
    end

    def to_cookie_header(io) : Nil
      io << @name
      io << '='
      io << @value
    end

    # Returns the expiration time of this cookie.
    def expiration_time : Time?
      if max_age = @max_age
        @creation_time + max_age
      else
        @expires
      end
    end

    # Returns the expiration status of this cookie as a `Bool`.
    #
    # *time_reference* can be passed to use a different reference time for
    # comparison. Default is the current time (`Time.utc`).
    def expired?(time_reference = Time.utc) : Bool
      if @max_age.try &.zero?
        true
      elsif expiration_time = self.expiration_time
        expiration_time <= time_reference
      else
        false
      end
    end

    # Returns `false` if `#name` has a security prefix but the requirements are not met as per
    # [RFC 6265 bis §4.1.3](https://datatracker.ietf.org/doc/html/draft-ietf-httpbis-rfc6265bis-07#section-4.1.3),
    # otherwise returns `true`.
    def valid? : Bool
      self.valid_secure_prefix? && self.valid_host_prefix?
    end

    # Raises `ArgumentError` if `self` is not `#valid?`.
    def validate! : self
      raise ArgumentError.new "Invalid cookie name. Has '__Secure-' prefix, but is not secure." unless self.valid_secure_prefix?
      raise ArgumentError.new "Invalid cookie name. Does not meet '__Host-' prefix requirements of: secure: true, path: \"/\", domain: nil." unless self.valid_host_prefix?

      self
    end

    private def valid_secure_prefix? : Bool
      self.secure || !@name.starts_with?("__Secure-")
    end

    private def valid_host_prefix? : Bool
      !@name.starts_with?("__Host-") || (self.secure && "/" == @path && @domain.nil?)
    end

    private def check_prefix : Nil
      if @name.starts_with?("__Host-")
        @path = "/" if @path.nil?
        @secure = true if @secure.nil?
      end

      if @name.starts_with?("__Secure-")
        @secure = true if @secure.nil?
      end
    end

    # :nodoc:
    module Parser
      module Regex
        CookieName     = /[^()<>@,;:\\"\/\[\]?={} \t\x00-\x1f\x7f]+/
        CookieOctet    = /[!#-+\--:<-\[\]-~]/
        CookieValue    = /(?:"#{CookieOctet}*"|#{CookieOctet}*)/
        CookiePair     = /(?<name>#{CookieName})=(?<value>#{CookieValue})/
        DomainLabel    = /[A-Za-z0-9\-]+/
        DomainIp       = /(?:\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})/
        Time           = /(?:\d{2}:\d{2}:\d{2})/
        Month          = /(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/
        Weekday        = /(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)/
        Wkday          = /(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)/
        PathValue      = /[^\x00-\x1f\x7f;]+/
        DomainValue    = /(?:#{DomainLabel}(?:\.#{DomainLabel})?|#{DomainIp})+/
        Zone           = /(?:UT|GMT|EST|EDT|CST|CDT|MST|MDT|PST|PDT|[+-]?\d{4})/
        RFC1036Date    = /#{Weekday}, \d{2}-#{Month}-\d{2} #{Time} GMT/
        RFC1123Date    = /#{Wkday}, \d{1,2} #{Month} \d{2,4} #{Time} #{Zone}/
        IISDate        = /#{Wkday}, \d{1,2}-#{Month}-\d{2,4} #{Time} GMT/
        ANSICDate      = /#{Wkday} #{Month} (?:\d{2}| \d) #{Time} \d{4}/
        SaneCookieDate = /(?:#{RFC1123Date}|#{RFC1036Date}|#{IISDate}|#{ANSICDate})/
        ExtensionAV    = /(?<extension>[^\x00-\x1f\x7f]+)/
        HttpOnlyAV     = /(?<http_only>HttpOnly)/i
        SameSiteAV     = /SameSite=(?<samesite>\w+)/i
        SecureAV       = /(?<secure>Secure)/i
        PathAV         = /Path=(?<path>#{PathValue})/i
        DomainAV       = /Domain=\.?(?<domain>#{DomainValue})/i
        MaxAgeAV       = /Max-Age=(?<max_age>[0-9]*)/i
        ExpiresAV      = /Expires=(?<expires>#{SaneCookieDate})/i
        CookieAV       = /(?:#{ExpiresAV}|#{MaxAgeAV}|#{DomainAV}|#{PathAV}|#{SecureAV}|#{HttpOnlyAV}|#{SameSiteAV}|#{ExtensionAV})/
      end

      CookieString    = /(?:^|; )#{Regex::CookiePair}/
      SetCookieString = /^#{Regex::CookiePair}(?:;\s*#{Regex::CookieAV})*$/

      def parse_cookies(header, &)
        header.scan(CookieString).each do |pair|
          value = pair["value"]
          if value.starts_with?('"')
            # Unwrap quoted cookie value
            value = value.byte_slice(1, value.bytesize - 2)
          end
          yield Cookie.new(pair["name"], value)
        end
      end

      def parse_cookies(header) : Array(Cookie)
        cookies = [] of Cookie
        parse_cookies(header) { |cookie| cookies << cookie }
        cookies
      end

      def parse_set_cookie(header) : Cookie?
        match = header.match(SetCookieString)
        return unless match

        expires = parse_time(match["expires"]?)
        max_age = match["max_age"]?.try(&.to_i64.seconds)

        Cookie.new(
          match["name"], match["value"],
          path: match["path"]?,
          expires: expires,
          domain: match["domain"]?,
          secure: match["secure"]? != nil,
          http_only: match["http_only"]? != nil,
          samesite: match["samesite"]?.try { |v| SameSite.parse? v },
          extension: match["extension"]?,
          max_age: max_age,
        )
      end

      private def parse_time(string)
        return unless string
        HTTP.parse_time(string)
      end

      extend self
    end
  end

  # Represents a collection of cookies as it can be present inside
  # a HTTP request or response.
  #
  # NOTE: To use `Cookies`, you must explicitly import it with `require "http/cookie"`
  class Cookies
    include Enumerable(Cookie)

    # Creates a new instance by parsing the `Cookie` and `Set-Cookie`
    # headers in the given `HTTP::Headers`.
    #
    # See `HTTP::Request#cookies` and `HTTP::Client::Response#cookies`.
    @[Deprecated("Use `.from_client_headers` or `.from_server_headers` instead.")]
    def self.from_headers(headers) : self
      new.tap(&.fill_from_headers(headers))
    end

    # Filling cookies by parsing the `Cookie` and `Set-Cookie`
    # headers in the given `HTTP::Headers`.
    @[Deprecated("Use `#fill_from_client_headers` or `#fill_from_server_headers` instead.")]
    def fill_from_headers(headers)
      fill_from_client_headers(headers)
      fill_from_server_headers(headers)
      self
    end

    # Creates a new instance by parsing the `Cookie` headers in the given `HTTP::Headers`.
    #
    # See `HTTP::Client::Response#cookies`.
    def self.from_client_headers(headers) : self
      new.tap(&.fill_from_client_headers(headers))
    end

    # Filling cookies by parsing the `Cookie` headers in the given `HTTP::Headers`.
    def fill_from_client_headers(headers) : self
      if values = headers.get?("Cookie")
        values.each do |header|
          Cookie::Parser.parse_cookies(header) { |cookie| self << cookie }
        end
      end
      self
    end

    # Creates a new instance by parsing the `Set-Cookie` headers in the given `HTTP::Headers`.
    #
    # See `HTTP::Request#cookies`.
    def self.from_server_headers(headers) : self
      new.tap(&.fill_from_server_headers(headers))
    end

    # Filling cookies by parsing the `Set-Cookie` headers in the given `HTTP::Headers`.
    def fill_from_server_headers(headers) : self
      if values = headers.get?("Set-Cookie")
        values.each do |header|
          Cookie::Parser.parse_set_cookie(header).try { |cookie| self << cookie }
        end
      end
      self
    end

    # Creates a new empty instance.
    def initialize
      @cookies = {} of String => Cookie
    end

    # Sets a new cookie in the collection with a string value.
    # This creates a never expiring, insecure, not HTTP-only cookie with
    # no explicit domain restriction and no path.
    #
    # ```
    # require "http/client"
    #
    # request = HTTP::Request.new "GET", "/"
    # request.cookies["foo"] = "bar"
    # ```
    def []=(key, value : String)
      self[key] = Cookie.new(key, value)
    end

    # Sets a new cookie in the collection to the given `HTTP::Cookie`
    # instance. The name attribute must match the given *key*, else
    # `ArgumentError` is raised.
    #
    # ```
    # require "http/client"
    #
    # response = HTTP::Client::Response.new(200)
    # response.cookies["foo"] = HTTP::Cookie.new("foo", "bar", "/admin", Time.utc + 12.hours, secure: true)
    # ```
    def []=(key, value : Cookie)
      unless key == value.name
        raise ArgumentError.new("Cookie name must match the given key")
      end

      @cookies[key] = value
    end

    # Gets the current `HTTP::Cookie` for the given *key*.
    #
    # ```
    # request.cookies["foo"].value # => "bar"
    # ```
    def [](key) : Cookie
      @cookies[key]
    end

    # Gets the current `HTTP::Cookie` for the given *key* or `nil` if none is set.
    #
    # ```
    # require "http/client"
    #
    # request = HTTP::Request.new "GET", "/"
    # request.cookies["foo"]? # => nil
    # request.cookies["foo"] = "bar"
    # request.cookies["foo"]?.try &.value # > "bar"
    # ```
    def []?(key) : Cookie?
      @cookies[key]?
    end

    # Returns `true` if a cookie with the given *key* exists.
    #
    # ```
    # request.cookies.has_key?("foo") # => true
    # ```
    def has_key?(key) : Bool
      @cookies.has_key?(key)
    end

    # Adds the given *cookie* to this collection, overrides an existing cookie
    # with the same name if present.
    #
    # ```
    # response.cookies << HTTP::Cookie.new("foo", "bar", http_only: true)
    # ```
    def <<(cookie : Cookie)
      self[cookie.name] = cookie
    end

    # Clears the collection, removing all cookies.
    def clear : Hash(String, HTTP::Cookie)
      @cookies.clear
    end

    # Deletes and returns the `HTTP::Cookie` for the specified *key*, or
    # returns `nil` if *key* cannot be found in the collection. Note that
    # *key* should match the name attribute of the desired `HTTP::Cookie`.
    def delete(key) : Cookie?
      @cookies.delete(key)
    end

    # Yields each `HTTP::Cookie` in the collection.
    def each(& : Cookie ->)
      @cookies.each_value do |cookie|
        yield cookie
      end
    end

    # Returns an iterator over the cookies of this collection.
    def each
      @cookies.each_value
    end

    # Returns the number of cookies contained in this collection.
    def size : Int32
      @cookies.size
    end

    # Whether the collection contains any cookies.
    def empty? : Bool
      @cookies.empty?
    end

    # Adds `Cookie` headers for the cookies in this collection to the
    # given `HTTP::Headers` instance and returns it. Removes any existing
    # `Cookie` headers in it.
    def add_request_headers(headers)
      if empty?
        headers.delete("Cookie")
      else
        capacity = sum { |cookie| cookie.name.bytesize + cookie.value.bytesize + 1 }
        capacity += (size - 1) * 2
        headers["Cookie"] = String.build(capacity) do |io|
          join(io, "; ", &.to_cookie_header(io))
        end
      end

      headers
    end

    # Adds `Set-Cookie` headers for the cookies in this collection to the
    # given `HTTP::Headers` instance and returns it. Removes any existing
    # `Set-Cookie` headers in it.
    def add_response_headers(headers)
      headers.delete("Set-Cookie")
      each do |cookie|
        headers.add("Set-Cookie", cookie.to_set_cookie_header)
      end

      headers
    end

    # Returns this collection as a plain `Hash`.
    def to_h : Hash(String, Cookie)
      @cookies.dup
    end
  end
end
