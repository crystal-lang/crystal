require "./common"
require "uri"
require "http/params"
require "socket"

# An HTTP request.
#
# It serves both to perform requests by an `HTTP::Client` and to
# represent requests received by an `HTTP::Server`.
#
# A request always holds an `IO` as a body.
# When creating a request with a `String` or `Bytes` its body
# will be a `IO::Memory` wrapping these, and the `Content-Length`
# header will be set appropriately.
#
# NOTE: To use `Request`, you must explicitly import it with `require "http/request"`
class HTTP::Request
  property method : String
  property headers : Headers
  getter body : IO?
  property version : String
  @cookies : Cookies?
  @query_params : URI::Params?
  @form_params : HTTP::Params?
  @uri : URI?

  # The network address that sent the request to an HTTP server.
  #
  # `HTTP::Server` will try to fill this property, and its value
  # will have a format like "IP:port", but this format is not guaranteed.
  # Middlewares can overwrite this value.
  #
  # Example:
  #
  # ```
  # class ForwarderHandler
  #   include HTTP::Handler
  #
  #   def call(context)
  #     if ip = context.request.headers["X-Real-IP"]? # When using a reverse proxy that guarantees this field.
  #       context.request.remote_address = Socket::IPAddress.new(ip, 0)
  #     end
  #     call_next(context)
  #   end
  # end
  #
  # server = HTTP::Server.new([ForwarderHandler.new, HTTP::LogHandler.new])
  # ```
  #
  # This property is not used by `HTTP::Client`.
  property remote_address : Socket::Address?

  # The network address of the HTTP server.
  #
  # `HTTP::Server` will try to fill this property, and its value
  # will have a format like "IP:port", but this format is not guaranteed.
  # Middlewares can overwrite this value.
  #
  # This property is not used by `HTTP::Client`.
  property local_address : Socket::Address?

  def self.new(method : String, resource : String, headers : Headers? = nil, body : String | Bytes | IO | Nil = nil, version = "HTTP/1.1")
    # Duplicate headers to prevent the request from modifying data that the user might hold.
    new(method, resource, headers.try(&.dup), body, version, internal: nil)
  end

  private def initialize(@method : String, @resource : String, headers : Headers? = nil, body : String | Bytes | IO | Nil = nil, @version = "HTTP/1.1", *, internal)
    @headers = headers || Headers.new
    self.body = body
  end

  # Returns a convenience wrapper around querying and setting cookie related
  # headers, see `HTTP::Cookies`.
  def cookies : HTTP::Cookies
    @cookies ||= Cookies.from_client_headers(headers)
  end

  # Returns a convenience wrapper around querying and setting query params,
  # see `URI::Params`.
  def query_params : URI::Params
    @query_params ||= uri.query_params
  end

  # Returns a convenience wrapper to parse form params, see `URI::Params`.
  # Returns `nil` in case the content type `"application/x-www-form-urlencoded"`
  # is not present or the body is `nil`.
  def form_params? : HTTP::Params?
    @form_params ||= begin
      if headers["Content-Type"]? == "application/x-www-form-urlencoded"
        if body = self.body
          HTTP::Params.parse(body.gets_to_end)
        end
      end
    end
  end

  # Returns a convenience wrapper to parse form params, see `URI::Params`.
  def form_params : HTTP::Params
    form_params? || HTTP::Params.new
  end

  def resource : String
    update_uri
    @uri.try(&.request_target) || @resource
  end

  def keep_alive? : Bool
    HTTP.keep_alive?(self)
  end

  def ignore_body? : Bool
    @method == "HEAD"
  end

  def content_length=(length : Int)
    headers["Content-Length"] = length.to_s
  end

  def content_length
    HTTP.content_length(headers)
  end

  def body=(body : String)
    @body = IO::Memory.new(body)
    self.content_length = body.bytesize
  end

  def body=(body : Bytes)
    @body = IO::Memory.new(body)
    self.content_length = body.size
  end

  def body=(@body : IO)
  end

  def body=(@body : Nil)
    @headers["Content-Length"] = "0" if @method.in?("POST", "PUT")
  end

  def to_io(io)
    io << @method << ' ' << resource << ' ' << @version << "\r\n"
    cookies = @cookies
    headers = cookies ? cookies.add_request_headers(@headers) : @headers
    HTTP.serialize_headers_and_body(io, headers, nil, @body, @version)
  end

  # :nodoc:
  record RequestLine, method : String, resource : String, http_version : String

  # Returns a `HTTP::Request` instance if successfully parsed,
  # `nil` on EOF or `HTTP::Status` otherwise.
  def self.from_io(io, *, max_request_line_size : Int32 = HTTP::MAX_REQUEST_LINE_SIZE, max_headers_size : Int32 = HTTP::MAX_HEADERS_SIZE) : HTTP::Request | HTTP::Status | Nil
    line = parse_request_line(io, max_request_line_size)
    return line unless line.is_a?(RequestLine)

    status = HTTP.parse_headers_and_body(io, max_headers_size: max_headers_size) do |headers, body|
      # No need to dup headers since nobody else holds them
      request = new line.method, line.resource, headers, body, line.http_version, internal: nil

      if io.responds_to?(:remote_address)
        request.remote_address = io.remote_address
      end

      if io.responds_to?(:local_address)
        request.local_address = io.local_address
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

  # Returns the request's path component.
  def path : String
    uri.path.presence || "/"
  end

  # Sets request's path component.
  def path=(path)
    uri.path = path
  end

  # Lazily parses and returns the request's query component.
  def query : String?
    update_uri
    uri.query
  end

  # Sets request's query component.
  def query=(value)
    uri.query = value
    update_query_params
    value
  end

  # Extracts the hostname from `Host` header.
  #
  # Returns `nil` if the `Host` header is missing.
  #
  # If the `Host` header contains a port number, it is stripped off.
  def hostname : String?
    header = @headers["Host"]?
    return unless header

    host, _, port = header.rpartition(":")
    if host.empty?
      # no colon in header
      host = header
    else
      port = port.to_i?(whitespace: false)
      unless port && Socket::IPAddress.valid_port?(port)
        # what we identified as port is not valid, so use the entire header
        host = header
      end
    end

    URI.unwrap_ipv6(host)
  end

  # Returns request host with port from headers.
  @[Deprecated(%q(Use `headers["Host"]?` instead.))]
  def host_with_port : String?
    @headers["Host"]?
  end

  private def uri
    (@uri ||= URI.parse(@resource)).not_nil!
  end

  private def update_query_params
    return unless @query_params
    @query_params = uri.query_params
  end

  private def update_uri
    return unless @query_params
    uri.query = query_params.to_s
  end

  def if_match : Array(String)?
    parse_etags("If-Match")
  end

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
      case reader.current_char
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
      case reader.current_char
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
