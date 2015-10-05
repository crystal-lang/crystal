require "openssl"
require "socket"
require "uri"
require "base64"
require "../common"

# An HTTP Client.
#
# ### One-shot usage
#
# Without a block, an `HTTP::Response` is returned and the response's body
# is available as a `String` by invoking `HTTP::Response#body`.
#
# ```
# require "http/client"
#
# response = HTTP::Client.get "http://www.example.com"
# response.status_code #=> 200
# response.body.lines.first #=> "<!doctype html>"
# ```
#
# With a block, an `HTTP::Response` body is returned and the response's body
# is available as an `IO` by invoking `HTTP::Response#body_io`.
#
# ```
# require "http/client"
#
# HTTP::Client.get("http://www.example.com") do |response|
#   response.status_code  #=> 200
#   response.body_io.gets #=> "<!doctype html>"
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
# response.status_code #=> 200
# response.body.lines.first #=> "<!doctype html>"
# client.close
# ```
class HTTP::Client
  # Returns the target host.
  #
  # ```
  # client = HTTP::Client.new "www.example.com"
  # client.host #=> "www.example.com"
  # ```
  getter host

  # Returns the target port.
  #
  # ```
  # client = HTTP::Client.new "www.example.com"
  # client.port #=> 80
  # ```
  getter port

  # Returns whether this client is using SSL.
  #
  # ```
  # client = HTTP::Client.new "www.example.com", ssl: true
  # client.ssl? #=> true
  # ```
  getter? ssl

  # Creates a new HTTP client with the given *host*, *port* and *ssl*
  # configurations. If no port is given, the default one will
  # be used depending on the *ssl* arguments: 80 for if *ssl* is `false`,
  # 443 if *ssl* is `true`.
  def initialize(@host, port = nil, @ssl = false)
    @port = port || (ssl ? 443 : 80)
  end

  # Creates a new HTTP client, yields it to the block, and closes
  # the client afterwards.
  #
  # ```
  # HTTP::Client.new("www.example.com") do |client|
  #   client.get "/"
  # end
  # ```
  def self.new(host, port = nil, ssl = false)
    client = new(host, port, ssl)
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

  # Set the number of seconds to wait when reading before raising an `IO::Timeout`.
  #
  # ```
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

  # Set the read timeout with a `Time::Span`, to wait when reading before raising an `IO::Timeout`.
  #
  # ```
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

  # Set the number of seconds to wait when connecting, before raising an `IO::Timeout`.
  #
  # ```
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

  # Set the open timeout with a `Time::Span` to wait when connecting, before raising an `IO::Timeout`.
  #
  # ```
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

  # Adds a callback to execute before each request. This is usually
  # used to set an authorization header. Any number of callbacks
  # can be added.
  #
  #
  # ```
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

  {% for method in %w(get post put head delete patch) %}
    # Executes a {{method.id.upcase}} request.
    # The response will have its body as a `String`, accessed via `HTTP::Response#body`.
    #
    # ```
    # client = HTTP::Client.new("www.example.com")
    # response = client.{{method.id}}("/", headers: HTTP::Headers{"User-agent": "AwesomeApp"}, body: "Hello!")
    # response.body #=> "..."
    # ```
    def {{method.id}}(path, headers = nil : HTTP::Headers?, body = nil : String?) : HTTP::Response
      exec {{method.upcase}}, path, headers, body
    end

    # Executes a {{method.id.upcase}} request and yields the response to the block.
    # The response will have its body as an `IO` accessed via `HTTP::Response#body_io`.
    #
    # ```
    # client = HTTP::Client.new("www.example.com")
    # client.{{method.id}}("/", headers: HTTP::Headers{"User-agent": "AwesomeApp"}, body: "Hello!") do |response|
    #   response.body_io.gets #=> "..."
    # end
    # ```
    def {{method.id}}(path, headers = nil : HTTP::Headers?, body = nil : String?)
      exec {{method.upcase}}, path, headers, body do |response|
        yield response
      end
    end

    # Executes a {{method.id.upcase}} request.
    # The response will have its body as a `String`, accessed via `HTTP::Response#body`.
    #
    # ```
    # response = HTTP::Client.{{method.id}}("/", headers: HTTP::Headers{"User-agent": "AwesomeApp"}, body: "Hello!")
    # response.body #=> "..."
    # ```
    def self.{{method.id}}(url : String | URI, headers = nil : HTTP::Headers?, body = nil : String?) : HTTP::Response
      exec {{method.upcase}}, url, headers, body
    end

    # Executes a {{method.id.upcase}} request and yields the response to the block.
    # The response will have its body as an `IO` accessed via `HTTP::Response#body_io`.
    #
    # ```
    # HTTP::Client.{{method.id}}("/", headers: HTTP::Headers{"User-agent": "AwesomeApp"}, body: "Hello!") do |response|
    #   response.body_io.gets #=> "..."
    # end
    # ```
    def self.{{method.id}}(url : String | URI, headers = nil : HTTP::Headers?, body = nil : String?)
      exec {{method.upcase}}, url, headers, body do |response|
        yield response
      end
    end
  {% end %}

  # Executes a POST with form data. The "Content-type" header is set
  # to "application/x-www-form-urlencoded".
  #
  # ```
  # client = HTTP::Client.new "www.example.com"
  # response = client.post_form "/", "foo=bar"
  # ```
  def post_form(path, form : String, headers = nil : HTTP::Headers?) : HTTP::Response
    headers ||= HTTP::Headers.new
    headers["Content-type"] = "application/x-www-form-urlencoded"
    post path, headers, form
  end

  # Executes a POST with form data. The "Content-type" header is set
  # to "application/x-www-form-urlencoded".
  #
  # ```
  # client = HTTP::Client.new "www.example.com"
  # response = client.post_form "/", {"foo": "bar"}
  # ```
  def post_form(path, form : Hash, headers = nil : HTTP::Headers?) : HTTP::Response
    body = HTTP::Params.build do |form_builder|
      form.each do |key, value|
        form_builder.add key, value
      end
    end

    post_form path, body, headers
  end

  # Executes a POST with form data. The "Content-type" header is set
  # to "application/x-www-form-urlencoded".
  #
  # ```
  # response = HTTP::Client.post_form "http://www.example.com", "foo=bar"
  # ```
  def self.post_form(url, form : String | Hash, headers = nil : HTTP::Headers?) : HTTP::Response
    exec(url) do |client, path|
      client.post_form(path, form, headers)
    end
  end

  # Executes a request.
  # The response will have its body as a `String`, accessed via `HTTP::Response#body`.
  #
  # ```
  # client = HTTP::Client.new "www.example.com"
  # response = client.exec HTTP::Request.new("GET", "/")
  # response.body #=> "..."
  # ```
  def exec(request : HTTP::Request) : HTTP::Response
    execute_callbacks(request)
    request.headers["User-agent"] ||= "Crystal"
    request.to_io(socket)
    socket.flush
    HTTP::Response.from_io(socket, request.ignore_body?).tap do |response|
      close unless response.keep_alive?
    end
  end

  # Executes a request request and yields an `HTTP::Response` to the block.
  # The response will have its body as an `IO` accessed via `HTTP::Response#body_io`.
  #
  # ```
  # client = HTTP::Client.new "www.example.com"
  # client.exec(HTTP::Request.new("GET", "/")) do |response|
  #   response.body_io.gets #=> "..."
  # end
  # ```
  def exec(request : HTTP::Request, &block)
    execute_callbacks(request)
    request.headers["User-agent"] ||= "Crystal"
    request.to_io(socket)
    socket.flush
    HTTP::Response.from_io(socket, request.ignore_body?) do |response|
      value = yield response
      response.body_io.try &.close
      close unless response.keep_alive?
      value
    end
  end

  # Executes a request.
  # The response will have its body as a `String`, accessed via `HTTP::Response#body`.
  #
  # ```
  # client = HTTP::Client.new "www.example.com"
  # response = client.exec "GET", "/"
  # response.body #=> "..."
  # ```
  def exec(method : String, path, headers = nil : HTTP::Headers?, body = nil : String?) : HTTP::Response
    exec new_request method, path, headers, body
  end

  # Executes a request.
  # The response will have its body as an `IO` accessed via `HTTP::Response#body_io`.
  #
  # ```
  # client = HTTP::Client.new "www.example.com"
  # client.exec("GET", "/") do |response|
  #   response.body_io.gets #=> "..."
  # end
  # ```
  def exec(method : String, path, headers = nil : HTTP::Headers?, body = nil : String?)
    exec(new_request(method, path, headers, body)) do |response|
      yield response
    end
  end

  # Executes a request.
  # The response will have its body as an `IO` accessed via `HTTP::Response#body_io`.
  #
  # ```
  # response = HTTP::Client.exec "GET", "http://www.example.com"
  # response.body #=> "..."
  # ```
  def self.exec(method, url : String | URI, headers = nil : HTTP::Headers?, body = nil : String?) : HTTP::Response
    exec(url) do |client, path|
      client.exec method, path, headers, body
    end
  end

  # Executes a request.
  # The response will have its body as an `IO` accessed via `HTTP::Response#body_io`.
  #
  # ```
  # HTTP::Client.exec("GET", "http://www.example.com") do |response|
  #   response.body_io.gets #=> "..."
  # end
  # ```
  def self.exec(method, url : String | URI, headers = nil : HTTP::Headers?, body = nil : String?)
    exec(url) do |client, path|
      client.exec(method, path, headers, body) do |response|
        yield response
      end
    end
  end

  # Closes this client. If used again, a new connection will be opened.
  def close
    @ssl_socket.try &.close
    @ssl_socket = nil

    @socket.try &.close
    @socket = nil
  end

  private def new_request(method, path, headers, body)
    headers ||= HTTP::Headers.new
    headers["Host"] ||= host_header
    HTTP::Request.new method, path, headers, body
  end

  private def execute_callbacks(request)
    @before_request.try &.each &.call(request)
  end

  private def socket
    socket = @socket ||= TCPSocket.new @host, @port, nil, @connect_timeout
    socket.read_timeout = @read_timeout if @read_timeout
    socket.sync = false
    if @ssl
      @ssl_socket ||= OpenSSL::SSL::Socket.new(socket)
    else
      socket
    end
  end

  private def host_header
    if (@ssl && @port != 443) || (!@ssl && @port != 80)
      "#{@host}:#{@port}"
    else
      @host
    end
  end

  private def self.exec(uri)
    uri = URI.parse(uri) if uri.is_a?(String)

    unless uri.scheme
      raise ArgumentError.new %(Request URI must have schema. Possibly add "http://" to the request URI?)
    end

    host = uri.host.not_nil!
    port = uri.port
    path = uri.full_path
    user = uri.user
    password = uri.password
    ssl = false

    case uri.scheme
    when "http"
      # Nothing
    when "https"
      ssl = true
    else
      raise "Unsuported scheme: #{uri.scheme}"
    end

    HTTP::Client.new(host, port, ssl) do |client|
      if user && password
        client.basic_auth(user, password)
      end
      yield client, path
    end
  end
end
