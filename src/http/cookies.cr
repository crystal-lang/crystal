require "./cookie"

module HTTP
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

    def_equals_and_hash @cookies

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
      self << Cookie.new(key, value)
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

      self << value
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
      @cookies[cookie.name] = cookie
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

    # Returns a string representation of this cookies list.
    #
    # It uses the `Set-Cookie` serialization from `Cookie#to_set_cookie_header` which
    # represents the full state of the cookie.
    #
    # ```
    # HTTP::Cookies{
    #   HTTP::Cookie.new("foo", "bar"),
    #   HTTP::Cookie.new("foo", "bar", domain: "example.com"),
    # }.to_s # => "HTTP::Cookies{\"foo=bar\", \"foo=bar; domain=example.com\"}"
    # ```
    def to_s(io : IO)
      io << "HTTP::Cookies{"
      join(io, ", ") { |cookie| cookie.to_set_cookie_header.inspect(io) }
      io << "}"
    end

    # :ditto:
    def inspect(io : IO)
      to_s(io)
    end

    # :ditto:
    def pretty_print(pp) : Nil
      pp.list("HTTP::Cookies{", self, "}") { |elem| pp.text(elem.to_set_cookie_header.inspect) }
    end
  end
end
