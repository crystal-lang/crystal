require "cgi"
require "./common"

module HTTP
  class Cookie
    def self.parse(str : String) : Cookie
      # TODO: error handling, empty string + no name=value pair
      parts = str.split(/[;]\s?/)
      name, value = parts[0].split(/\s*=\s*/, 2)

      cookie = HTTP::Cookie.new(name, value)
      (1...parts.size).each do |i|
        part = parts[i]
        case part
        when .=~ /^\s*path=(.+)/i
          cookie.path = $~[1] if $~
        when .=~ /^\s*domain=(.+)/i
          cookie.domain = $~[1] if $~
        when .=~ /Secure/
          cookie.secure = true
        when .=~ /HttpOnly/
          cookie.http_only = true
        when .=~ /^\s*expires=(.+)/
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

    def initialize(@name, value, @path = "/",  @expires = nil, @domain = nil, @secure = false, @http_only = false)
      @value = CGI.unescape value
    end

    def to_header
      String.build do |header|
        header << "#{@name}=#{CGI.escape value}"
        header << "; path=#{@path}" if @path
        header << "; expires=#{HTTP.rfc1123_date(@expires as Time)}" if @expires
        header << "; domain=#{@domain}" if @domain
        header << "; Secure" if @secure
        header << "; HttpOnly" if @http_only
      end
    end
  end

  class Cookies
    include Enumerable(Cookie)

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

    def initialize
      @cookies = {} of String => Cookie
    end

    def []=(key, value)
      @cookies[key] = value
    end

    def [](key)
      @cookies[key]
    end

    def <<(cookie : Cookie)
      self[cookie.name] = cookie
    end

    def each(&block : T -> _)
      @cookies.values.each do |cookie|
        yield cookie
      end
    end

    def add_request_headers(headers)
      add_headers "Cookie", headers
    end

    def add_response_headers(headers)
      add_headers "Set-Cookie", headers
    end

    private def add_headers key, headers
      each do |cookie|
        headers.add(key, cookie.to_header)
      end

      headers
    end
  end
end
