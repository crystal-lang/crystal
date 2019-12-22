# An HTTP Client.
#
# ### One-shot usage
#
# Without a block, an `HTTP::Client::Response` is returned and the response's body
# is available as a `String` by invoking `HTTP::Client::Response#body`.
#
# ```
# require "http/client"
#
# response = HTTP::Client.get "http://www.example.com"
# response.status_code      # => 200
# response.body.lines.first # => "<!doctype html>"
# ```
#
# ### Parameters
#
# Parameters can be added to any request with the `HTTP::Params#encode` method, which
# converts a `Hash` or `NamedTuple` to a URL encoded HTTP query.
#
# ```
# require "http/client"
#
# params = HTTP::Params.encode({"author" => "John Doe", "offset" => "20"}) # => author=John+Doe&offset=20
# response = HTTP::Client.get "http://www.example.com?" + params
# response.status_code # => 200
# ```
#
# ### Streaming
#
# With a block, an `HTTP::Client::Response` body is returned and the response's body
# is available as an `IO` by invoking `HTTP::Client::Response#body_io`.
#
# ```
# require "http/client"
#
# HTTP::Client.get("http://www.example.com") do |response|
#   response.status_code  # => 200
#   response.body_io.gets # => "<!doctype html>"
# end
# ```
#
# ### Reusing a connection
#
# Similar to the above cases, but creating an instance of an `HTTP::Client`.
#
# ```
# require "http/client"
#
# client = HTTP::Client.new "www.example.com"
# response = client.get "/"
# response.status_code      # => 200
# response.body.lines.first # => "<!doctype html>"
# client.close
# ```
#
# ### Compression
#
# If `compress` isn't set to `false`, and no `Accept-Encoding` header is explicitly specified,
# an HTTP::Client will add an `"Accept-Encoding": "gzip, deflate"` header, and automatically decompress
# the response body/body_io.
#
# ### Encoding
#
# If a response has a `Content-Type` header with a charset, that charset is set as the encoding
# of the returned IO (or used for creating a String for the body). Invalid bytes in the given encoding
# are silently ignored when reading text content.
class HTTP::Client
  # The set of possible valid body types.
  alias BodyType = String | Bytes | IO | Nil

  # Returns the target host.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new "www.example.com"
  # client.host # => "www.example.com"
  # ```
  getter host : String

  # Returns the target port.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new "www.example.com"
  # client.port # => 80
  # ```
  getter port : Int32

  # If this client uses TLS, returns its `OpenSSL::SSL::Context::Client`, raises otherwise.
  #
  # Changes made after the initial request will have no effect.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new "www.example.com", tls: true
  # client.tls # => #<OpenSSL::SSL::Context::Client ...>
  # ```
  {% if flag?(:without_openssl) %}
    getter! tls : Nil
  {% else %}
    getter! tls : OpenSSL::SSL::Context::Client
  {% end %}

  # Whether automatic compression/decompression is enabled.
  property? compress : Bool

  {% if flag?(:without_openssl) %}
    @socket : TCPSocket | Nil
  {% else %}
    @socket : TCPSocket | OpenSSL::SSL::Socket | Nil
  {% end %}

  @dns_timeout : Float64?
  @connect_timeout : Float64?
  @read_timeout : Float64?
  @write_timeout : Float64?

  # Creates a new HTTP client with the given *host*, *port* and *tls*
  # configurations. If no port is given, the default one will
  # be used depending on the *tls* arguments: 80 for if *tls* is `false`,
  # 443 if *tls* is truthy. If *tls* is `true` a new `OpenSSL::SSL::Context::Client` will
  # be used, else the given one. In any case the active context can be accessed through `tls`.
  {% if flag?(:without_openssl) %}
    def initialize(@host : String, port = nil, tls : Bool = false)
      check_host_only(@host)

      @tls = nil
      if tls
        raise "HTTP::Client TLS is disabled because `-D without_openssl` was passed at compile time"
      end

      @port = (port || (@tls ? 443 : 80)).to_i
      @compress = true
    end
  {% else %}
    def initialize(@host : String, port = nil, tls : Bool | OpenSSL::SSL::Context::Client = false)
      check_host_only(@host)

      @tls = case tls
             when true
               OpenSSL::SSL::Context::Client.new
             when OpenSSL::SSL::Context::Client
               tls
             when false
               nil
             end

      @port = (port || (@tls ? 443 : 80)).to_i
      @compress = true
    end
  {% end %}

  private def check_host_only(string : String)
    # When parsing a URI with just a host
    # we end up with a URI with just a path
    uri = URI.parse(string)
    if uri.scheme || uri.host || uri.port || uri.query || uri.user || uri.password || uri.path.includes?('/')
      raise_invalid_host(string)
    end
  rescue URI::Error
    raise_invalid_host(string)
  end

  private def raise_invalid_host(string : String)
    raise ArgumentError.new("The string passed to create an HTTP::Client must be just a host, not #{string.inspect}")
  end

  # Creates a new HTTP client from a URI. Parses the *host*, *port*,
  # and *tls* configuration from the URI provided. Port defaults to
  # 80 if not specified unless using the https protocol, which defaults
  # to port 443 and sets tls to `true`.
  #
  # ```
  # require "http/client"
  # require "uri"
  #
  # uri = URI.parse("https://secure.example.com")
  # client = HTTP::Client.new(uri)
  #
  # client.tls? # => #<OpenSSL::SSL::Context::Client>
  # client.get("/")
  # ```
  # This constructor will *ignore* any path or query segments in the URI
  # as those will need to be passed to the client when a request is made.
  #
  # If *tls* is given it will be used, if not a new TLS context will be created.
  # If *tls* is given and *uri* is a HTTP URI, `ArgumentError` is raised.
  # In any case the active context can be accessed through `tls`.
  #
  # This constructor will raise an exception if any scheme but HTTP or HTTPS
  # is used.
  def self.new(uri : URI, tls = nil)
    tls = tls_flag(uri, tls)
    host = validate_host(uri)
    new(host, uri.port, tls)
  end

  # Creates a new HTTP client from a URI, yields it to the block and closes the
  # client afterwards. Parses the *host*, *port*, and *tls* configuration from
  # the URI provided. Port defaults to 80 if not specified unless using the
  # https protocol, which defaults to port 443 and sets tls to `true`.
  #
  # ```
  # require "http/client"
  # require "uri"
  #
  # uri = URI.parse("https://secure.example.com")
  # HTTP::Client.new(uri) do |client|
  #   client.tls? # => #<OpenSSL::SSL::Context::Client>
  #   client.get("/")
  # end
  # ```
  # This constructor will *ignore* any path or query segments in the URI
  # as those will need to be passed to the client when a request is made.
  #
  # If *tls* is given it will be used, if not a new TLS context will be created.
  # If *tls* is given and *uri* is a HTTP URI, `ArgumentError` is raised.
  # In any case the active context can be accessed through `tls`.
  #
  # This constructor will raise an exception if any scheme but HTTP or HTTPS
  # is used.
  def self.new(uri : URI, tls = nil)
    tls = tls_flag(uri, tls)
    host = validate_host(uri)
    client = new(host, uri.port, tls)
    begin
      yield client
    ensure
      client.close
    end
  end

  # Creates a new HTTP client, yields it to the block, and closes
  # the client afterwards.
  #
  # ```
  # require "http/client"
  #
  # HTTP::Client.new("www.example.com") do |client|
  #   client.get "/"
  # end
  # ```
  def self.new(host : String, port = nil, tls = false)
    client = new(host, port, tls)
    begin
      yield client
    ensure
      client.close
    end
  end

  # Configures this client to perform basic authentication in every
  # request.
  def basic_auth(username, password)
    header = "Basic #{Base64.strict_encode("#{username}:#{password}")}"
    before_request do |request|
      request.headers["Authorization"] = header
    end
  end

  # Sets the number of seconds to wait when reading before raising an `IO::Timeout`.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new("example.org")
  # client.read_timeout = 1.5
  # begin
  #   response = client.get("/")
  # rescue IO::Timeout
  #   puts "Timeout!"
  # end
  # ```
  def read_timeout=(read_timeout : Number)
    @read_timeout = read_timeout.to_f
  end

  # Sets the read timeout with a `Time::Span`, to wait when reading before raising an `IO::Timeout`.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new("example.org")
  # client.read_timeout = 5.minutes
  # begin
  #   response = client.get("/")
  # rescue IO::Timeout
  #   puts "Timeout!"
  # end
  # ```
  def read_timeout=(read_timeout : Time::Span)
    self.read_timeout = read_timeout.total_seconds
  end

  # Sets the write timeout - if any chunk of request is not written
  # within the number of seconds provided, `IO::Timeout` exception is raised.
  def write_timeout=(write_timeout : Number)
    @write_timeout = write_timeout.to_f
  end

  # Sets the write timeout - if any chunk of request is not written
  # within the provided `Time::Span`,  `IO::Timeout` exception is raised.
  def write_timeout=(write_timeout : Time::Span)
    self.write_timeout = write_timeout.total_seconds
  end

  # Sets the number of seconds to wait when connecting, before raising an `IO::Timeout`.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new("example.org")
  # client.connect_timeout = 1.5
  # begin
  #   response = client.get("/")
  # rescue IO::Timeout
  #   puts "Timeout!"
  # end
  # ```
  def connect_timeout=(connect_timeout : Number)
    @connect_timeout = connect_timeout.to_f
  end

  # Sets the open timeout with a `Time::Span` to wait when connecting, before raising an `IO::Timeout`.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new("example.org")
  # client.connect_timeout = 5.minutes
  # begin
  #   response = client.get("/")
  # rescue IO::Timeout
  #   puts "Timeout!"
  # end
  # ```
  def connect_timeout=(connect_timeout : Time::Span)
    self.connect_timeout = connect_timeout.total_seconds
  end

  # **This method has no effect right now**
  #
  # Sets the number of seconds to wait when resolving a name, before raising an `IO::Timeout`.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new("example.org")
  # client.dns_timeout = 1.5
  # begin
  #   response = client.get("/")
  # rescue IO::Timeout
  #   puts "Timeout!"
  # end
  # ```
  def dns_timeout=(dns_timeout : Number)
    @dns_timeout = dns_timeout.to_f
  end

  # **This method has no effect right now**
  #
  # Sets the number of seconds to wait when resolving a name with a `Time::Span`, before raising an `IO::Timeout`.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new("example.org")
  # client.dns_timeout = 1.5.seconds
  # begin
  #   response = client.get("/")
  # rescue IO::Timeout
  #   puts "Timeout!"
  # end
  # ```
  def dns_timeout=(dns_timeout : Time::Span)
    self.dns_timeout = dns_timeout.total_seconds
  end

  # Adds a callback to execute before each request. This is usually
  # used to set an authorization header. Any number of callbacks
  # can be added.
  #
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new("www.example.com")
  # client.before_request do |request|
  #   request.headers["Authorization"] = "XYZ123"
  # end
  # client.get "/"
  # ```
  def before_request(&callback : HTTP::Request ->)
    before_request = @before_request ||= [] of (HTTP::Request ->)
    before_request << callback
  end

  {% for method in %w(get post put head delete patch options) %}
    # Executes a {{method.id.upcase}} request.
    # The response will have its body as a `String`, accessed via `HTTP::Client::Response#body`.
    #
    # ```
    # require "http/client"
    #
    # client = HTTP::Client.new("www.example.com")
    # response = client.{{method.id}}("/", headers: HTTP::Headers{"User-Agent" => "AwesomeApp"}, body: "Hello!")
    # response.body #=> "..."
    # ```
    def {{method.id}}(path, headers : HTTP::Headers? = nil, body : BodyType = nil) : HTTP::Client::Response
      exec {{method.upcase}}, path, headers, body
    end

    # Executes a {{method.id.upcase}} request and yields the response to the block.
    # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
    #
    # ```
    # require "http/client"
    #
    # client = HTTP::Client.new("www.example.com")
    # client.{{method.id}}("/", headers: HTTP::Headers{"User-Agent" => "AwesomeApp"}, body: "Hello!") do |response|
    #   response.body_io.gets #=> "..."
    # end
    # ```
    def {{method.id}}(path, headers : HTTP::Headers? = nil, body : BodyType = nil)
      exec {{method.upcase}}, path, headers, body do |response|
        yield response
      end
    end

    # Executes a {{method.id.upcase}} request.
    # The response will have its body as a `String`, accessed via `HTTP::Client::Response#body`.
    #
    # ```
    # require "http/client"
    #
    # response = HTTP::Client.{{method.id}}("/", headers: HTTP::Headers{"User-Agent" => "AwesomeApp"}, body: "Hello!")
    # response.body #=> "..."
    # ```
    def self.{{method.id}}(url : String | URI, headers : HTTP::Headers? = nil, body : BodyType = nil, tls = nil) : HTTP::Client::Response
      exec {{method.upcase}}, url, headers, body, tls
    end

    # Executes a {{method.id.upcase}} request and yields the response to the block.
    # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
    #
    # ```
    # require "http/client"
    #
    # HTTP::Client.{{method.id}}("/", headers: HTTP::Headers{"User-Agent" => "AwesomeApp"}, body: "Hello!") do |response|
    #   response.body_io.gets #=> "..."
    # end
    # ```
    def self.{{method.id}}(url : String | URI, headers : HTTP::Headers? = nil, body : BodyType = nil, tls = nil)
      exec {{method.upcase}}, url, headers, body, tls do |response|
        yield response
      end
    end

    # Executes a {{method.id.upcase}} request with form data and returns a `Response`. The "Content-Type" header is set
    # to "application/x-www-form-urlencoded".
    #
    # ```
    # require "http/client"
    #
    # client = HTTP::Client.new "www.example.com"
    # response = client.{{method.id}} "/", form: "foo=bar"
    # ```
    def {{method.id}}(path, headers : HTTP::Headers? = nil, *, form : String | IO) : HTTP::Client::Response
      request = new_request({{method.upcase}}, path, headers, form)
      request.headers["Content-Type"] = "application/x-www-form-urlencoded"
      exec request
    end

    # Executes a {{method.id.upcase}} request with form data and yields the response to the block.
    # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
    # The "Content-Type" header is set to "application/x-www-form-urlencoded".
    #
    # ```
    # require "http/client"
    #
    # client = HTTP::Client.new "www.example.com"
    # client.{{method.id}}("/", form: "foo=bar") do |response|
    #   response.body_io.gets
    # end
    # ```
    def {{method.id}}(path, headers : HTTP::Headers? = nil, *, form : String | IO)
      request = new_request({{method.upcase}}, path, headers, form)
      request.headers["Content-Type"] = "application/x-www-form-urlencoded"
      exec(request) do |response|
        yield response
      end
    end

    # Executes a {{method.id.upcase}} request with form data and returns a `Response`. The "Content-Type" header is set
    # to "application/x-www-form-urlencoded".
    #
    # ```
    # require "http/client"
    #
    # client = HTTP::Client.new "www.example.com"
    # response = client.{{method.id}} "/", form: {"foo" => "bar"}
    # ```
    def {{method.id}}(path, headers : HTTP::Headers? = nil, *, form : Hash(String, String) | NamedTuple) : HTTP::Client::Response
      body = HTTP::Params.encode(form)
      {{method.id}} path, form: body, headers: headers
    end

    # Executes a {{method.id.upcase}} request with form data and yields the response to the block.
    # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
    # The "Content-type" header is set to "application/x-www-form-urlencoded".
    #
    # ```
    # require "http/client"
    #
    # client = HTTP::Client.new "www.example.com"
    # client.{{method.id}}("/", form: {"foo" => "bar"}) do |response|
    #   response.body_io.gets
    # end
    # ```
    def {{method.id}}(path, headers : HTTP::Headers? = nil, *, form : Hash(String, String) | NamedTuple)
      body = HTTP::Params.encode(form)
      {{method.id}}(path, form: body, headers: headers) do |response|
        yield response
      end
    end

    # Executes a {{method.id.upcase}} request with form data and returns a `Response`. The "Content-Type" header is set
    # to "application/x-www-form-urlencoded".
    #
    # ```
    # require "http/client"
    #
    # response = HTTP::Client.{{method.id}} "http://www.example.com", form: "foo=bar"
    # ```
    def self.{{method.id}}(url, headers : HTTP::Headers? = nil, tls = nil, *, form : String | IO | Hash) : HTTP::Client::Response
      exec(url, tls) do |client, path|
        client.{{method.id}}(path, form: form, headers: headers)
      end
    end

    # Executes a {{method.id.upcase}} request with form data and yields the response to the block.
    # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
    # The "Content-Type" header is set to "application/x-www-form-urlencoded".
    #
    # ```
    # require "http/client"
    #
    # HTTP::Client.{{method.id}}("http://www.example.com", form: "foo=bar") do |response|
    #   response.body_io.gets
    # end
    # ```
    def self.{{method.id}}(url, headers : HTTP::Headers? = nil, tls = nil, *, form : String | IO | Hash)
      exec(url, tls) do |client, path|
        client.{{method.id}}(path, form: form, headers: headers) do |response|
          yield response
        end
      end
    end
  {% end %}

  # Executes a request.
  # The response will have its body as a `String`, accessed via `HTTP::Client::Response#body`.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new "www.example.com"
  # response = client.exec HTTP::Request.new("GET", "/")
  # response.body # => "..."
  # ```
  def exec(request : HTTP::Request) : HTTP::Client::Response
    exec_internal(request)
  end

  private def exec_internal(request)
    response = exec_internal_single(request)
    return handle_response(response) if response

    # Server probably closed the connection, so retry one
    close
    request.body.try &.rewind
    response = exec_internal_single(request)
    return handle_response(response) if response

    raise "Unexpected end of http response"
  end

  private def exec_internal_single(request)
    decompress = send_request(request)
    HTTP::Client::Response.from_io?(socket, ignore_body: request.ignore_body?, decompress: decompress)
  end

  private def handle_response(response)
    close unless response.keep_alive?
    response
  end

  # Executes a request request and yields an `HTTP::Client::Response` to the block.
  # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new "www.example.com"
  # client.exec(HTTP::Request.new("GET", "/")) do |response|
  #   response.body_io.gets # => "..."
  # end
  # ```
  def exec(request : HTTP::Request, &block)
    exec_internal(request) do |response|
      yield response
    end
  end

  private def exec_internal(request, &block : Response -> T) : T forall T
    exec_internal_single(request) do |response|
      if response
        return handle_response(response) { yield response }
      end

      # Server probably closed the connection, so retry once
      close
      request.body.try &.rewind
      exec_internal_single(request) do |response|
        if response
          return handle_response(response) do
            yield response
          end
        end
      end
    end
    raise "Unexpected end of http response"
  end

  private def exec_internal_single(request)
    decompress = send_request(request)
    HTTP::Client::Response.from_io?(socket, ignore_body: request.ignore_body?, decompress: decompress) do |response|
      yield response
    end
  end

  private def handle_response(response)
    value = yield
    response.body_io?.try &.close
    close unless response.keep_alive?
    value
  end

  private def send_request(request)
    decompress = set_defaults request
    run_before_request_callbacks(request)
    request.to_io(socket)
    socket.flush
    decompress
  end

  private def set_defaults(request)
    request.headers["Host"] ||= host_header
    request.headers["User-Agent"] ||= "Crystal"
    {% if flag?(:without_zlib) %}
      false
    {% else %}
      if compress? && !request.headers.has_key?("Accept-Encoding")
        request.headers["Accept-Encoding"] = "gzip, deflate"
        true
      else
        false
      end
    {% end %}
  end

  # For one-shot headers we don't want keep-alive (might delay closing the response)
  private def self.default_one_shot_headers(headers)
    headers ||= HTTP::Headers.new
    headers["Connection"] ||= "close"
    headers
  end

  private def run_before_request_callbacks(request)
    @before_request.try &.each &.call(request)
  end

  # Executes a request.
  # The response will have its body as a `String`, accessed via `HTTP::Client::Response#body`.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new "www.example.com"
  # response = client.exec "GET", "/"
  # response.body # => "..."
  # ```
  def exec(method : String, path, headers : HTTP::Headers? = nil, body : BodyType = nil) : HTTP::Client::Response
    exec new_request method, path, headers, body
  end

  # Executes a request.
  # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
  #
  # ```
  # require "http/client"
  #
  # client = HTTP::Client.new "www.example.com"
  # client.exec("GET", "/") do |response|
  #   response.body_io.gets # => "..."
  # end
  # ```
  def exec(method : String, path, headers : HTTP::Headers? = nil, body : BodyType = nil)
    exec(new_request(method, path, headers, body)) do |response|
      yield response
    end
  end

  # Executes a request.
  # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
  #
  # ```
  # require "http/client"
  #
  # response = HTTP::Client.exec "GET", "http://www.example.com"
  # response.body # => "..."
  # ```
  def self.exec(method, url : String | URI, headers : HTTP::Headers? = nil, body : BodyType = nil, tls = nil) : HTTP::Client::Response
    headers = default_one_shot_headers(headers)
    exec(url, tls) do |client, path|
      client.exec method, path, headers, body
    end
  end

  # Executes a request.
  # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
  #
  # ```
  # require "http/client"
  #
  # HTTP::Client.exec("GET", "http://www.example.com") do |response|
  #   response.body_io.gets # => "..."
  # end
  # ```
  def self.exec(method, url : String | URI, headers : HTTP::Headers? = nil, body : BodyType = nil, tls = nil)
    headers = default_one_shot_headers(headers)
    exec(url, tls) do |client, path|
      client.exec(method, path, headers, body) do |response|
        yield response
      end
    end
  end

  # Closes this client. If used again, a new connection will be opened.
  def close
    @socket.try &.close
    @socket = nil
  end

  private def new_request(method, path, headers, body : BodyType)
    HTTP::Request.new(method, path, headers, body)
  end

  private def socket
    socket = @socket
    return socket if socket

    hostname = @host.starts_with?('[') && @host.ends_with?(']') ? @host[1..-2] : @host
    socket = TCPSocket.new hostname, @port, @dns_timeout, @connect_timeout
    socket.read_timeout = @read_timeout if @read_timeout
    socket.write_timeout = @write_timeout if @write_timeout
    socket.sync = false

    {% if !flag?(:without_openssl) %}
      if tls = @tls
        tcp_socket = socket
        begin
          socket = OpenSSL::SSL::Socket::Client.new(tcp_socket, context: tls, sync_close: true, hostname: @host)
        rescue exc
          # don't leak the TCP socket when the SSL connection failed
          tcp_socket.close
          raise exc
        end
      end
    {% end %}

    @socket = socket
  end

  private def host_header
    if (@tls && @port != 443) || (!@tls && @port != 80)
      "#{@host}:#{@port}"
    else
      @host
    end
  end

  private def self.exec(string : String, tls = nil)
    uri = URI.parse(string)

    unless uri.scheme && uri.host
      # Assume http if no scheme and host are specified
      uri = URI.parse("http://#{string}")
    end

    exec(uri, tls) do |client, path|
      yield client, path
    end
  end

  {% if flag?(:without_openssl) %}
    protected def self.tls_flag(uri, context : Nil)
      scheme = uri.scheme
      case scheme
      when nil
        raise ArgumentError.new("Missing scheme: #{uri}")
      when "http"
        false
      when "https"
        true
      else
        raise ArgumentError.new "Unsupported scheme: #{scheme}"
      end
    end
  {% else %}
    protected def self.tls_flag(uri, context : OpenSSL::SSL::Context::Client?)
      scheme = uri.scheme
      case {scheme, context}
      when {nil, _}
        raise ArgumentError.new("Missing scheme: #{uri}")
      when {"http", nil}
        false
      when {"http", OpenSSL::SSL::Context::Client}
        raise ArgumentError.new("TLS context given for HTTP URI")
      when {"https", nil}
        true
      when {"https", OpenSSL::SSL::Context::Client}
        context
      else
        raise ArgumentError.new "Unsupported scheme: #{scheme}"
      end
    end
  {% end %}

  protected def self.validate_host(uri)
    host = uri.host.presence
    return host if host

    raise ArgumentError.new %(Request URI must have host (URI is: #{uri}))
  end

  private def self.exec(uri : URI, tls = nil)
    tls = tls_flag(uri, tls)
    host = validate_host(uri)

    port = uri.port
    path = uri.full_path
    user = uri.user
    password = uri.password

    HTTP::Client.new(host, port, tls) do |client|
      if user && password
        client.basic_auth(user, password)
      end
      yield client, path
    end
  end
end

{% if !flag?(:without_openssl) %}
  require "openssl"
{% end %}
require "socket"
require "uri"
require "base64"
require "./client/response"
require "./common"
