require "./common"

module HTTP
  # Represents a cookie with all its attributes. Provides convenient
  # access and modification of them.
  class Cookie
    def self.parse(str : String) : Cookie
      # TODO: error handling, empty string + no name=value pair
      parts = str.split(/[;]\s?/)
      name, value = parts[0].split(/\s*=\s*/, 2)

      cookie = HTTP::Cookie.new(name, value)
      (1...parts.size).each do |i|
        part = parts[i]
        case part
        when /^\s*path=(.+)/i
          cookie.path = $~[1] if $~
        when /^\s*domain=(.+)/i
          cookie.domain = $~[1] if $~
        when /Secure/
          cookie.secure = true
        when /HttpOnly/
          cookie.http_only = true
        when /^\s*expires=(.+)/
          cookie.expires = HTTP.parse_time($~[1]) if $~
        end
      end

      cookie
    end

    property name
    property value
    property path
    property expires
    property domain
    property secure
    property http_only

    def_equals_and_hash name, value, path, expires, domain, secure, http_only

    def initialize(@name : String, value : String, @path = "/" : String,
                   @expires = nil : Time?, @domain = nil : String?,
                   @secure = false : Bool, @http_only = false : Bool)
      @value = URI.unescape value
    end

    def to_header
      path    = @path
      expires = @expires
      domain  = @domain
      String.build do |header|
        header << "#{@name}=#{URI.escape value}"
        header << "; path=#{path}" if path
        header << "; expires=#{HTTP.rfc1123_date(expires)}" if expires
        header << "; domain=#{domain}" if domain
        header << "; Secure" if @secure
        header << "; HttpOnly" if @http_only
      end
    end
  end

  # Represents a collection of cookies as it can be present inside
  # a HTTP request or response.
  class Cookies
    include Enumerable(Cookie)

    # Create a new instance by parsing the `Cookie` and `Set-Cookie`
    # headers in the given `HTTP::Headers`.
    #
    # See `HTTP::Request#cookies` and `HTTP::Response#cookies`.
    def self.from_headers(headers)
      new.tap do |cookies|
        {"Cookie", "Set-Cookie"}.each do |key|
          if values = headers.get?(key)
            values.each do |header|
              cookies << Cookie.parse(header)
            end
            headers.delete key
          end
        end
      end
    end

    # Create a new empty instance
    def initialize
      @cookies = {} of String => Cookie
    end

    # Set a new cookie in the collection with a string value.
    # This creates a never expiring, insecure, not HTTP only cookie with
    # no explicit domain restriction and the path `/`.
    #
    # ```
    # request.cookies["foo"] = "bar"
    # ```
    def []=(key, value : String)
      self[key] = Cookie.new(key, value)
    end

    # Set a new cookie in the collection to the given `HTTP::Cookie`
    # instance. The name attribute must match the given *key*, else
    # `ArgumentError` is raised.
    #
    # ```
    # response.cookies["foo"] = HTTP::Cookie.new("foo", "bar", "/admin", Time.now + 12.hours, secure: true)
    # ```
    def []=(key, value : Cookie)
      unless key == value.name
        raise ArgumentError.new("Cookie name must match the given key")
      end

      @cookies[key] = value
    end

    # Get the current `HTTP::Cookie` for the given *key*.
    #
    # ```
    # request.cookies["foo"].value #=> "bar"
    # ```
    def [](key)
      @cookies[key]
    end

    # Get the current `HTTP::Cookie` for the given *key* or `nil` if none is set.
    #
    # ```
    # request.cookies["foo"]? #=> nil
    # request.cookies["foo"] = "bar"
    # request.cookies["foo"]?.try &.value #> "bar"
    # ```
    def []?(key)
      @cookies[key]?
    end

    # Returns `true` if a cookie with the given *key* exists.
    #
    # ```
    # request.cookies.has_key?("foo") #=> true
    def has_key?(key)
      @cookies.has_key?(key)
    end

    # Add the given *cookie* to this collection, overrides an existing cookie
    # with the same name if present.
    #
    # ```
    # response.cookies << Cookie.new("foo", "bar", http_only: true)
    # ```
    def <<(cookie : Cookie)
      self[cookie.name] = cookie
    end

    # Yields each `HTTP::Cookie` in the collection.
    def each(&block : T -> _)
      @cookies.values.each do |cookie|
        yield cookie
      end
    end

    # Returns an iterator over the cookies of this collection.
    def each
      @cookies.each_value
    end

    # Adds `Cookie` headers for the cookies in this collection to the
    # given `HTTP::Header` instance and returns it. Removes any existing
    # `Cookie` headers in it.
    def add_request_headers(headers)
      add_headers "Cookie", headers
    end

    # Adds `Set-Cookie` headers for the cookies in this collection to the
    # given `HTTP::Header` instance and returns it. Removes any existing
    # `Set-Cookie` headers in it.
    def add_response_headers(headers)
      add_headers "Set-Cookie", headers
    end

    private def add_headers key, headers
      headers.delete(key)

      each do |cookie|
        headers.add(key, cookie.to_header)
      end

      headers
    end
  end
end
