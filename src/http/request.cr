require "./common"
require "uri"
require "http/params"

# An HTTP request.
#
# It serves both to perform requests by an `HTTP::Client` and to
# represent requests received by an `HTTP::Server`.
#
# A request always holds an `IO` as a body.
# When creating a request with a `String` or `Bytes` its body
# will be a `IO::Memory` wrapping these, and the `Content-Length`
# header will be set appropriately.
class HTTP::Request
  property method : String
  property headers : Headers
  getter body : IO?
  property version : String
  @cookies : Cookies?
  @query_params : Params?
  @uri : URI?

  # The network address that sent the request to an HTTP server.
  #
  # `HTTP::Server` will try to fill this property, and its value
  # will have a format like "IP:port", but this format is not guaranteed.
  # Middlewares can overwrite this value.
  #
  # This property is not used by `HTTP::Client`.
  property remote_address : String?

  # Creates a new HTTP Request.
  #
  # ```crystal
  # require "http/request"
  #
  # HTTP::Request.new("GET", "/", HTTP::Headers{"host" => "crystal-lang.org", "hello crystal!"})
  # ```
  def self.new(method : String, resource : String, headers : Headers? = nil, body : String | Bytes | IO | Nil = nil, version = "HTTP/1.1") : self
    # Duplicate headers to prevent the request from modifying data that the user might hold.
    new(method, resource, headers.try(&.dup), body, version, internal: nil)
  end

  private def initialize(@method : String, @resource : String, headers : Headers? = nil, body : String | Bytes | IO | Nil = nil, @version = "HTTP/1.1", *, internal)
    @headers = headers || Headers.new
    self.body = body
  end

  # Returns a convenience wrapper around querying and setting cookie related
  # headers, see `HTTP::Cookies`.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("GET", "/")
  # request.cookies << HTTP::Cookie.new("host", "crystal-lang.org")
  # request.cookies # => <HTTP::Cookies @cookies={"host" => #<HTTP::Cookie @name="host", @value="crystal-lang.org" ...>}>
  # ```
  def cookies : Cookies
    @cookies ||= Cookies.from_headers(headers)
  end

  # Returns a convenience wrapper around querying and setting query params,
  # see `HTTP::Params`.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("GET", "/")
  # request.query_params["q"] = "crystal"
  # request.query_params # => HTTP::Params(@raw_params={"q" => ["crystal"]})
  # ```
  def query_params : HTTP::Params
    @query_params ||= parse_query_params
  end

  # Returns the *resource* of this request.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("GET", "/search")
  # request.resource # => "/search"
  # request.query_params["q"] = "crystal"
  # request.resource # => "/search?q=crystal"
  # ```
  def resource : String
    update_uri
    @uri.try(&.full_path) || @resource
  end

  # Returns `true` if the connection is persistence in compliance with [RFC 6223](https://tools.ietf.org/html/rfc6223) or [RFC 7230 §6.3](https://tools.ietf.org/html/rfc7230#section-6.3).
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("GET", "/search", version: "HTTP/1.0")
  # request.keep_alive? # => false
  # request.version = "HTTP/1.1"
  # request.keep_alive? # => true
  # ```
  def keep_alive? : Bool
    HTTP.keep_alive?(self)
  end

  # Returns `true` if the request type does not have a body.
  # This applies to `HEAD` requests.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/", version: "HTTP/1.0")
  # request.ignore_body? # => true
  # request.method = "GET"
  # request.ignore_body? # => false
  # ```
  def ignore_body? : Bool
    @method == "HEAD"
  end

  # Sets the content length of a request.  This can be differnt then the bytesize of the *body*
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/", body: "hello crystal!")
  # request.content_length = 3
  # request.content_length # => "3"
  # ```
  def content_length=(length : Int) : String
    headers["Content-Length"] = length.to_s
  end

  # Returns the content length of a request.  This can be differnt then the bytesize of the *body*
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/", body: "hello crystal!")
  # request.content_length # => "14"
  # ```
  def content_length : String
    HTTP.content_length(headers)
  end

  # Sets the *body* of a request by converting the `String` passed into an `IO`.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/")
  # request.body = "hello crystal!"
  # request.body # => <IO::Memory @buffer=Pointer(UInt8), @bytesize=14 ...>
  # ```
  def body=(body : String)
    @body = IO::Memory.new(body)
    self.content_length = body.bytesize
  end

  # Sets the *body* of a request by converting the `Bytes` passed into an `IO`.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/")
  # request.body = Bytes[0x99, 0x114, 0x121, 0x115, 0x116, 0x97, 0x108]
  # request.body # => <IO::Memory @buffer=Pointer(UInt8), @bytesize=14 ...>
  # ```
  def body=(body : Bytes)
    @body = IO::Memory.new(body)
    self.content_length = body.size
  end

  # Sets the *body* of a request to the `IO` object passed.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/")
  # request.body = IO::Memory.new("hello crystal!")
  # request.body # => <IO::Memory @buffer=Pointer(UInt8), @bytesize=14 ...>
  # ```
  def body=(@body : IO)
  end

  # Sets the *body* of a request to `nil`
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/")
  # request.body = nil
  # request.body # => nil
  # ```
  def body=(@body : Nil)
    @headers["Content-Length"] = "0" if @method == "POST" || @method == "PUT"
  end

  # Writes this request to *io* according to HTTP protocol specification.
  #
  # ```crystal
  # require "http/request"
  #
  # io = IO::Memory.new
  #
  # request = HTTP::Request.new("HEAD", "/")
  # request.to_io(io)
  #
  # io.to_s # => "HEAD / HTTP/1.1\r\n\r\n"
  # ```
  def to_io(io)
    io << @method << ' ' << resource << ' ' << @version << "\r\n"
    cookies = @cookies
    headers = cookies ? cookies.add_request_headers(@headers) : @headers
    HTTP.serialize_headers_and_body(io, headers, nil, @body, @version)
  end

  # :nodoc:
  record RequestLine, method : String, resource : String, http_version : String

  # Returns a `HTTP::Request` instance if successfully parsed, `nil` on EOF or `HTTP::Status` otherwise.
  #
  # ```
  # require "http/request"
  #
  # request = HTTP::Request.from_io(IO::Memory.new("GET / HTTP/1.1\r\n\r\n"))
  # request # => <HTTP::Request @method="GET", @headers=HTTP::Headers{}, @version="HTTP/1.1", @resource="/" ...>
  # ```
  def self.from_io(io, *, max_request_line_size : Int32 = HTTP::MAX_REQUEST_LINE_SIZE, max_headers_size : Int32 = HTTP::MAX_HEADERS_SIZE) : HTTP::Request | HTTP::Status | Nil
    line = parse_request_line(io, max_request_line_size)
    return line unless line.is_a?(RequestLine)

    status = HTTP.parse_headers_and_body(io, max_headers_size: max_headers_size) do |headers, body|
      # No need to dup headers since nobody else holds them
      request = new line.method, line.resource, headers, body, line.http_version, internal: nil

      if io.responds_to?(:remote_address)
        request.remote_address = io.remote_address.try &.to_s
      end

      return request
    end

    # Malformed or unexpectedly ended http request
    status || HTTP::Status::BAD_REQUEST
  end

  private METHODS = %w(GET HEAD POST PUT DELETE CONNECT OPTIONS PATCH TRACE)

  private def self.parse_request_line(io : IO, max_request_line_size) : RequestLine | HTTP::Status | Nil
    # Optimization: see if we have a peek buffer
    # (avoids a string allocation for the entire request line)
    if peek = io.peek
      # peek.empty? means there's no more input (EOF), so no more requests
      return nil if peek.empty?

      # See if we can find \n
      index = peek.index('\n'.ord.to_u8)
      if index
        return HTTP::Status::URI_TOO_LONG if index > max_request_line_size

        end_index = index

        # Also check (and discard) \r before that
        if index > 0 && peek[index - 1] == '\r'.ord.to_u8
          end_index -= 1
        end

        parts = parse_request_line(peek[0, end_index])
        io.skip(index + 1) # Must skip until after \n
        return parts
      end
    end

    request_line = io.gets(max_request_line_size + 1, chomp: true)
    return nil unless request_line

    # Identify Request-URI too long
    if request_line.bytesize > max_request_line_size
      return HTTP::Status::URI_TOO_LONG
    end

    parse_request_line(request_line)
  end

  private def self.parse_request_line(line : String) : RequestLine | HTTP::Status
    parse_request_line(line.to_slice)
  end

  private def self.parse_request_line(slice : Bytes) : RequestLine | HTTP::Status
    space_index = slice.index(' '.ord.to_u8)

    # Oops, only a single part (should be three)
    return HTTP::Status::BAD_REQUEST unless space_index

    subslice = slice[0...space_index]

    # Optimization: see if it's one of the common methods
    # (avoids a string allocation for these methods)
    method = METHODS.find { |method| method.to_slice == subslice } ||
             String.new(subslice)

    # Skip spaces.
    # The RFC just mentions a single space but most servers allow multiple.
    while space_index < slice.size && slice[space_index] == ' '.ord.to_u8
      space_index += 1
    end

    # Oops, we only found the "method" part followed by spaces
    return HTTP::Status::BAD_REQUEST if space_index == slice.size

    next_space_index = slice.index(' '.ord.to_u8, offset: space_index)

    # Oops, we only found two parts (should be three)
    return HTTP::Status::BAD_REQUEST unless next_space_index

    resource = String.new(slice[space_index...next_space_index])

    # Skip spaces again
    space_index = next_space_index
    while space_index < slice.size && slice[space_index] == ' '.ord.to_u8
      space_index += 1
    end

    next_space_index = slice.index(' '.ord.to_u8, offset: space_index) || slice.size

    subslice = slice[space_index...next_space_index]

    # Optimization: avoid allocating a string for common HTTP version
    http_version = HTTP::SUPPORTED_VERSIONS.find { |version| version.to_slice == subslice }
    return HTTP::Status::BAD_REQUEST unless http_version

    # Skip trailing spaces
    space_index = next_space_index
    while space_index < slice.size
      # Oops, we find something else (more than three parts)
      return HTTP::Status::BAD_REQUEST unless slice[space_index] == ' '.ord.to_u8
      space_index += 1
    end

    RequestLine.new method: method, resource: resource, http_version: http_version
  end

  # Returns the request's *path* component.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/search")
  # request.path # => "/search"
  # ```
  def path : String
    uri.path.presence || "/"
  end

  # Sets request's *path* component.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/")
  # request.path = "/search"
  # request.path # => "/search"
  # ```
  def path=(path : String) : String
    uri.path = path
  end

  # Lazily parses and returns the request's query component.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/search?q=crystal")
  # request.query # => q=crystal
  # ```
  def query : String?
    update_uri
    uri.query
  end

  # Sets request's *query* component.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/search")
  # request.query = "q=crystal"
  # request.resource # => "/search?q=crystal"
  # ```
  def query=(value : String) : String
    uri.query = value
    update_query_params
    value
  end

  # Returns request *host* from headers.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/search?q=crystal")
  # request.headers.add("host", "crystal-lang.com")
  # request.host # => "crystal-lang.org"
  # ```
  def host : String?
    host = @headers["Host"]?
    return unless host
    index = host.index(":")
    index ? host[0...index] : host
  end

  # Returns request *host* with port from headers.
  #
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("HEAD", "/search?q=crystal")
  # request.headers.add("host", "crystal-lang.com:80")
  # request.host_with_port # => "crystal-lang.org:80"
  # ```
  def host_with_port : String?
    @headers["Host"]?
  end

  private def uri
    (@uri ||= URI.parse(@resource)).not_nil!
  end

  private def parse_query_params
    HTTP::Params.parse(uri.query || "")
  end

  private def update_query_params
    return unless @query_params
    @query_params = parse_query_params
  end

  private def update_uri
    return unless @query_params
    uri.query = query_params.to_s
  end

  # Returns the parsed "if-match" header.
  #
  # ```crystal
  # request = HTTP::Request.new("GET", "/", HTTP::Headers{"If-Match" => "*"})
  # request.if_match # => ["*"]
  # ```
  def if_match : Array(String)?
    parse_etags("If-Match")
  end

  # Returns the parsed "if-none-match" header.
  # ```crystal
  # require "http/request"
  #
  # request = HTTP::Request.new("GET", "/", HTTP::Headers{"If-None-Match" => "*"})
  # request.if_none_match # => ["*"]
  # ```
  def if_none_match : Array(String)?
    parse_etags("If-None-Match")
  end

  private def parse_etags(header_name)
    header = headers[header_name]?

    return unless header
    return ["*"] if header == "*"

    etags = [] of String
    reader = Char::Reader.new(header)

    require_comma = false
    while reader.has_next?
      case char = reader.current_char
      when ' ', '\t'
        reader.next_char
      when ','
        reader.next_char
        require_comma = false
      when '"', 'W'
        if require_comma
          # return what we've got on error
          return etags
        end

        reader, etag = consume_etag(reader)
        if etag
          etags << etag
          require_comma = true
        else
          # return what we've got on error
          return etags
        end
      else
        # return what we've got on error
        return etags
      end
    end

    etags
  end

  private def consume_etag(reader)
    start = reader.pos

    if reader.current_char == 'W'
      reader.next_char
      return reader, nil if reader.current_char != '/' || !reader.has_next?
      reader.next_char
    end

    return reader, nil if reader.current_char != '"'
    reader.next_char

    while reader.has_next?
      case char = reader.current_char
      when '!', '\u{23}'..'\u{7E}', '\u{80}'..'\u{FF}'
        reader.next_char
      when '"'
        reader.next_char
        return reader, reader.string.byte_slice(start, reader.pos - start)
      else
        return reader, nil
      end
    end

    return reader, nil
  end
end
