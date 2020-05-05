require "./common"

module HTTP
  # Represents a cookie with all its attributes. Provides convenient access and modification of them.
  class Cookie
    # Possible values for the `SameSite` cookie as described in the [Same-site Cookies Draft](https://tools.ietf.org/html/draft-west-first-party-cookies-07#section-4.1.1).
    enum SameSite
      # Prevents the cookie from being sent by the browser in all cross-site browsing contexts.
      Strict

      # Allows the cookie to be sent by the browser during top-level navigations that use a [safe](https://tools.ietf.org/html/rfc7231#section-4.2.1) HTTP method.
      Lax
    end

    property name : String
    property value : String
    property path : String
    property expires : Time?
    property domain : String?
    property secure : Bool
    property http_only : Bool
    property samesite : SameSite?
    property extension : String?

    def_equals_and_hash name, value, path, expires, domain, secure, http_only

    # A basic `HTTP::Cookie` can be created with a given *name* and *value*.
    #
    # ```crystal
    # require "http/cookie"
    #
    # HTTP::Cookie.new("session", "god")
    # ```
    #
    # All properties can also be set through the initializer.
    #
    # ```crystal
    # require "http/cookie"
    #
    # HTTP::Cookies.new("session", "god", expires: Time.utc(3020, 1, 1), secure: true)
    # ```
    def initialize(@name : String, @value : String, @path : String = "/",
                   @expires : Time? = nil, @domain : String? = nil,
                   @secure : Bool = false, @http_only : Bool = false,
                   @samesite : SameSite? = nil, @extension : String? = nil)
    end

    # Returns a `String` representing the Cookie as a value for the `Set-Cookie` header as specified by [RFC 6265 §4.2](https://tools.ietf.org/html/rfc6265#section-4.1).
    #
    # ```crystal
    # require "http/cookie"
    #
    # cookie = HTTP::Cookie.new("session", "12ab34cd", domain: "play.crystal-lang.org", secure: true)
    # cookie.to_set_cookie_header # => "session=12ab34cd; domain=play.crystal-lang.org; path=/; Secure"
    # ```
    def to_set_cookie_header : String
      path = @path
      expires = @expires
      domain = @domain
      samesite = @samesite
      String.build do |header|
        to_cookie_header(header)
        header << "; domain=#{domain}" if domain
        header << "; path=#{path}" if path
        header << "; expires=#{HTTP.format_time(expires)}" if expires
        header << "; Secure" if @secure
        header << "; HttpOnly" if @http_only
        header << "; SameSite=#{samesite}" if samesite
        header << "; #{@extension}" if @extension
      end
    end

    # Returns a `String` representing the Cookie as a value for the `Cookie` header as specified by [RFC 6265 §4.2](https://tools.ietf.org/html/rfc6265#section-4.2).
    #
    # ````crystal
    # require "http/cookie"
    #
    # cookie = HTTP::Cookie.new("session", "12ab34cd", domain: "play.crystal-lang.org", secure: true)
    # cookie.to_cookie_header # => "session=12ab34cd"
    # ```
    def to_cookie_header : String
      String.build do |io|
        to_cookie_header(io)
      end
    end

    # :nodoc:
    private def to_cookie_header(io : IO) : String?
      URI.encode_www_form(@name, io)
      io << '='
      URI.encode_www_form(value, io)
    end

    # Returns `true` if the cookie is expired.
    #
    # ```crystal
    # require "http/cookie"
    #
    # cookie = HTTP::Cookie.new("session", "12ab34cd", expires: Time.utc(2020, 1, 1))
    # cookie.expired? # => true
    # cookie = HTTP::Cookie.new("session", "12ab34cd", expires: Time.utc(3020, 1, 1))
    # cookie.expires? # => false
    # ```
    def expired? : Bool
      if e = expires
        e <= Time.utc
      else
        false
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
        DomainAV       = /Domain=(?<domain>#{DomainValue})/i
        MaxAgeAV       = /Max-Age=(?<max_age>[0-9]*)/i
        ExpiresAV      = /Expires=(?<expires>#{SaneCookieDate})/i
        CookieAV       = /(?:#{ExpiresAV}|#{MaxAgeAV}|#{DomainAV}|#{PathAV}|#{SecureAV}|#{HttpOnlyAV}|#{SameSiteAV}|#{ExtensionAV})/
      end

      CookieString    = /(?:^|; )#{Regex::CookiePair}/
      SetCookieString = /^#{Regex::CookiePair}(?:;\s*#{Regex::CookieAV})*$/

      # Yields an `HTTP::Cookie` for each cookie in the header.
      #
      # ```crystal
      # require "http/cookie"
      #
      # names = [] of String
      # HTTP::Cookies::Parser.parse_cookies { |cookie| names << cookie.name }
      # names # => ["session"]
      # ```
      def parse_cookies(header : String) : Nil
        header.scan(CookieString).each do |pair|
          yield Cookie.new(URI.decode_www_form(pair["name"]), URI.decode_www_form(pair["value"]))
        end
      end

      # Parses a `String` into an `HTTP::Cookie`.
      #
      # ```crystal
      # require "http/cookie"
      #
      # cookie = HTTP::Cookies::Parser.parse_cookies("session=god")
      # cookie # => [<HTTP::Cookie @name="session" @value"god" ...>]
      # ```
      def parse_cookies(header : String) : Array(Cookie)
        cookies = [] of Cookie
        parse_cookies(header) { |cookie| cookies << cookie }
        cookies
      end

      # Returns an `HTTP::Cookie` for a given `String` in the set cookie formate conforming to the RFC 6265 Section 4.1 https://tools.ietf.org/html/rfc6265#section-4.1
      #
      # ```crystal
      # require "http/cookie"
      #
      # cookie = HTTP::Cookie::Parser.parse_set_cookie("session=god; path=/")
      # cookie # => <HTTP::Cookie @name="session" @value="god" @path="/" ...>
      # ```
      def parse_set_cookie(header : String) : Cookie?
        match = header.match(SetCookieString)
        return unless match

        expires = if max_age = match["max_age"]?
                    Time.utc + max_age.to_i64.seconds
                  else
                    parse_time(match["expires"]?)
                  end

        Cookie.new(
          URI.decode_www_form(match["name"]), URI.decode_www_form(match["value"]),
          path: match["path"]? || "/",
          expires: expires,
          domain: match["domain"]?,
          secure: match["secure"]? != nil,
          http_only: match["http_only"]? != nil,
          samesite: match["samesite"]?.try { |v| SameSite.parse? v },
          extension: match["extension"]?
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
  class Cookies
    include Enumerable(Cookie)

    # Creates a new instance by parsing the `Cookie` and `Set-Cookie`
    # headers in the given `HTTP::Headers`.
    #
    # See `HTTP::Request#cookies` and `HTTP::Client::Response#cookies`.
    #
    # ```crystal
    # require "http/cookie"
    #
    # headers = HTTP::Headers{"Cookie" => "session=god"}
    # cookies = HTTP::Cookies.from_headers(headers)
    # cookies # => <HTTP::Cookies @cookies={"session" => <HTTP::Cookie @name="session", @value="god" ...>}>
    # ```
    def self.from_headers(headers : Headers) : self
      new.tap { |cookies| cookies.fill_from_headers(headers) }
    end

    # Filling cookies by parsing the `Cookie` and `Set-Cookie`
    # headers in the given `HTTP::Headers`.
    #
    # ```crystal
    # require "http/cookie"
    #
    # headers = HTTP::Headers{"Cookie" => "session=key"}
    # cookies = HTTP::Cookies.new
    # cookies.fill_from_headers(headers)
    # cookies # => <HTTP::Cookies @cookies={"session" => <HTTP::Cookie @name="session", @value="god" ...>}>
    # ```
    def fill_from_headers(headers : Headers) : self
      if values = headers.get?("Cookie")
        values.each do |header|
          Cookie::Parser.parse_cookies(header) { |cookie| self << cookie }
        end
      end

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
    # This creates a never expiring, insecure, not HTTP only cookie with
    # no explicit domain restriction and the path `/`.
    #
    # ```
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies.new
    # cookies["session"] = "god" # => <HTTP::Cookie @name="session" @value="god" ...>
    # ```
    def []=(key : String, value : String) : Cookie
      self[key] = Cookie.new(key, value)
    end

    # Sets a new cookie in the collection to the given `HTTP::Cookie`
    # instance. The name attribute must match the given *key*, else
    # `ArgumentError` is raised.
    #
    # ```
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies.new
    # cookies["session"] = HTTP::Cookie.new("session", "god") # => <HTTP::Cookie @name="session" @value="god" ...>
    # cookies["user"] = HTTP::Cookie.new("session", "god")    # => raises ArgumentError
    # ```
    def []=(key : String, value : Cookie) : Cookie
      unless key == value.name
        raise ArgumentError.new("Cookie name must match the given key")
      end

      @cookies[key] = value
    end

    # Gets the current `HTTP::Cookie` for the given *key*.
    #
    # ```
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies{HTTP::Cookie.new("session", "god")}
    # cookies["session"] # => <HTTP::Cookie @name="session", @value="god" ... >
    # cookies["debug"]   # => raises KeyError
    # ```
    def [](key : String) : Cookie
      @cookies[key]
    end

    # Gets the current `HTTP::Cookie` for the given *key* or `nil` if none is set.
    #
    # ```
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies.new { HTTP::Cookie.new("session", "god") }
    # cookies["session"]? # => <HTTP::Cookie @name="session", @value="god" ... >
    # cookies["debug"]?   # => false
    # ```
    def []?(key : String) : Cookie?
      @cookies[key]?
    end

    # Returns `true` if a cookie with the given *key* exists.
    #
    # ```
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies.new { HTTP::Cookie.new("session", "god") }
    # cookies.has_key?("session") # => true
    # cookies.has_key?("user")    # => false
    # ```
    def has_key?(key : String) : Bool
      @cookies.has_key?(key)
    end

    # Adds the given *cookie* to this collection indexed as the name of the cookie.  If another cookie with the same name already exists, it is overriden.
    # with the same name if present.
    #
    # ```
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies.new { HTTP::Cookie.new("session", "god") }
    # cookies # => <HTTP::Cookies @cookies={"session" => <HTTP::Cookie @name="session", @value="god" ...>}>
    # cookies << HTTP::Cookie.new("session", "master")
    # cookies # => <HTTP::Cookies @cookies={"session" => <HTTP::Cookie @name="session", @value="master" ...>}>
    # ```
    def <<(cookie : Cookie) : Cookie
      self[cookie.name] = cookie
    end

    # Clears the collection, removing all cookies.
    #
    # ```
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies.new { HTTP::Cookie.new("session", "god") }
    # cookies.size # => 1
    # cookies.clean
    # cookies.size # => 0
    # ```
    def clear : Hash(String, Cookie)
      @cookies.clear
    end

    # Deletes and returns the `HTTP::Cookie` for the specified *key*, or
    # returns `nil` if *key* cannot be found in the collection. Note that
    # *key* should match the name attribute of the desired `HTTP::Cookie`.
    #
    # ```crystal
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies.new { HTTP::Cookie.new("session", "god") }
    # cookies.delete("session") # => <HTTP::Cookie @name="session" @value="god" ...>
    # cookies.empty?            # => true
    # ```
    def delete(key : String) : Cookie?
      @cookies.delete(key)
    end

    # Iterates over all the *cookies* yielding each `Cookie` to the block.
    #
    # ```
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies{HTTP::Cookie.new("session", "god")}
    # cookies_hash = {} of String => String
    #
    # cookies.each do |cookie|
    #   cookie # => <HTTP::Cookie @name="session, @value="god" ...>
    #   cookies_hash[cookie.name] = cookie.value
    # end
    #
    # cookies_hash # => {"session" => "name"}
    # ```
    def each(&block : Cookie ->) : Nil
      @cookies.values.each do |cookie|
        yield cookie
      end
    end

    # Returns an `Iterator` over the cookies of this collection.
    #
    # ```crystal
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies{HTTP::Cookie.new("session", "god")}
    # cookies_iterator = cookies.each
    # cookies_iterator.next # => <HTTP::Cookie @name="session" @value="god">
    # ```
    def each : Iterator
      @cookies.each_value
    end

    # Returns the number of cookies contained in this collection.
    #
    # ```crystal
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies.new
    # cookies.size # => 0
    # cookies << HTTP::Cookie.new("session", "god")
    # cookies.size # => 1
    # ```
    def size : Int32
      @cookies.size
    end

    # Returns `true` if the collection contains any cookies.
    #
    # ```crystal
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies.new
    # cookies.empty? # => true
    # cookies << HTTP::Cookie.new("session", "god")
    # cookies.empty? # => false
    # ```
    def empty? : Bool
      @cookies.empty?
    end

    # Adds `Cookie` headers for the cookies in this collection to the
    # given `HTTP::Headers` instance and returns it. Removes any existing
    # `Cookie` headers in it.
    #
    # ```crystal
    # require "http/cookie"
    #
    # headers = HTTP::Headers.new
    # cookies = HTTP::Cookies{HTTP::Cookie.new("session", "god")}
    # headers = cookies.add_request_headers(headers)
    # headers # => HTTP::Headers{"Cookie" => "session=god"}
    # ```
    def add_request_headers(headers : Headers) : Headers
      headers.delete("Cookie")
      headers.add("Cookie", map(&.to_cookie_header).join("; ")) unless empty?

      headers
    end

    # Adds `Set-Cookie` headers for the cookies in this collection to the
    # given `HTTP::Headers` instance and returns it. Removes any existing
    # `Set-Cookie` headers in it.
    #
    # ```crystal
    # require "http/cookie"
    #
    # headers = HTTP::Headers.new
    # cookies = HTTP::Cookies{HTTP::Cookie.new("session", "god")}
    # headers = cookies.add_response_headers(headers)
    # headers # => HTTP::Headers{"Set-Cookie" => "session=god"}
    # ```
    def add_response_headers(headers : Headers) : Headers
      headers.delete("Set-Cookie")
      each do |cookie|
        headers.add("Set-Cookie", cookie.to_set_cookie_header)
      end

      headers
    end

    # Returns this collection as a plain `Hash`.
    #
    # ```crystal
    # require "http/cookie"
    #
    # cookies = HTTP::Cookies.new { HTTP::Cookie.new("session", "god") }
    # cookies.to_h # => {"session" => #<HTTP::Cookie:0x1083f9d20 @name="session", @value="god">}
    # ```
    def to_h : Hash(String, Cookie)
      @cookies.dup
    end
  end
end
