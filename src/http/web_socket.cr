class HTTP::WebSocket
  getter? closed = false

  # :nodoc:
  def initialize(io : IO)
    initialize(Protocol.new(io))
  end

  # :nodoc:
  def initialize(@ws : Protocol)
    @buffer = Bytes.new(4096)
    @current_message = IO::Memory.new
  end

  # Opens a new websocket using the information provided by the URI. This will also handle the handshake
  # and will raise an exception if the handshake did not complete successfully. This method will also raise
  # an exception if the URI is missing the host and/or the path.
  #
  # Please note that the scheme will only be used to identify if TLS should be used or not. Therefore, schemes
  # apart from `wss` and `https` will be treated as the default which is `ws`.
  #
  # ```
  # HTTP::WebSocket.new(URI.parse("ws://websocket.example.com/chat"))        # Creates a new WebSocket to `websocket.example.com`
  # HTTP::WebSocket.new(URI.parse("wss://websocket.example.com/chat"))       # Creates a new WebSocket with TLS to `websocket.example.com`
  # HTTP::WebSocket.new(URI.parse("http://websocket.example.com:8080/chat")) # Creates a new WebSocket to `websocket.example.com` on port `8080`
  # HTTP::WebSocket.new(URI.parse("ws://websocket.example.com/chat"),        # Creates a new WebSocket to `websocket.example.com` with an Authorization header
  #   HTTP::Headers{"Authorization" => "Bearer authtoken"})
  # ```
  def self.new(uri : URI | String, headers = HTTP::Headers.new)
    new(Protocol.new(uri, headers: headers))
  end

  # Opens a new websocket to the target host. This will also handle the handshake
  # and will raise an exception if the handshake did not complete successfully.
  #
  # ```
  # HTTP::WebSocket.new("websocket.example.com", "/chat")            # Creates a new WebSocket to `websocket.example.com`
  # HTTP::WebSocket.new("websocket.example.com", "/chat", tls: true) # Creates a new WebSocket with TLS to `ẁebsocket.example.com`
  # ```
  def self.new(host : String, path : String, port = nil, tls = false, headers = HTTP::Headers.new)
    new(Protocol.new(host, path, port, tls, headers))
  end

  def on_ping(&@on_ping : String ->)
  end

  def on_pong(&@on_pong : String ->)
  end

  def on_message(&@on_message : String ->)
  end

  def on_binary(&@on_binary : Bytes ->)
  end

  def on_close(&@on_close : String ->)
  end

  protected def check_open
    raise IO::Error.new "Closed socket" if closed?
  end

  def send(message)
    check_open
    @ws.send(message)
  end

  # It's possible to send a PING frame, which the client must respond to
  # with a PONG, or the server can send an unsolicited PONG frame
  # which the client should not respond to.
  #
  # See `#pong`.
  def ping(message = nil)
    check_open
    @ws.ping(message)
  end

  # Server can send an unsolicited PONG frame which the client should not respond to.
  #
  # See `#ping`.
  def pong(message = nil)
    check_open
    @ws.pong(message)
  end

  def stream(binary = true, frame_size = 1024)
    check_open
    @ws.stream(binary: binary, frame_size: frame_size) do |io|
      yield io
    end
  end

  def close(message = nil)
    return if closed?
    @closed = true
    @ws.close(message)
  end

  def run
    loop do
      begin
        info = @ws.receive(@buffer)
      rescue IO::EOFError
        @on_close.try &.call("")
        break
      end

      case info.opcode
      when Protocol::Opcode::PING
        @current_message.write @buffer[0, info.size]
        if info.final
          message = @current_message.to_s
          @on_ping.try &.call(message)
          pong(message) unless closed?
          @current_message.clear
        end
      when Protocol::Opcode::PONG
        @current_message.write @buffer[0, info.size]
        if info.final
          @on_pong.try &.call(@current_message.to_s)
          @current_message.clear
        end
      when Protocol::Opcode::TEXT
        @current_message.write @buffer[0, info.size]
        if info.final
          @on_message.try &.call(@current_message.to_s)
          @current_message.clear
        end
      when Protocol::Opcode::BINARY
        @current_message.write @buffer[0, info.size]
        if info.final
          @on_binary.try &.call(@current_message.to_slice)
          @current_message.clear
        end
      when Protocol::Opcode::CLOSE
        @current_message.write @buffer[0, info.size]
        if info.final
          message = @current_message.to_s
          @on_close.try &.call(message)
          close(message) unless closed?
          @current_message.clear
          break
        end
      end
    end
  end
end

require "./web_socket/*"
