require "./client"
require "./headers"

class HTTP::WebSocket
  getter? closed = false

  # :nodoc:
  def initialize(io : IO, sync_close = true)
    initialize(Protocol.new(io, sync_close: sync_close))
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
  # require "http/web_socket"
  #
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
  # require "http/web_socket"
  #
  # HTTP::WebSocket.new("websocket.example.com", "/chat")            # Creates a new WebSocket to `websocket.example.com`
  # HTTP::WebSocket.new("websocket.example.com", "/chat", tls: true) # Creates a new WebSocket with TLS to `ẁebsocket.example.com`
  # ```
  def self.new(host : String, path : String, port = nil, tls : HTTP::Client::TLSContext = nil, headers = HTTP::Headers.new)
    new(Protocol.new(host, path, port, tls, headers))
  end

  # Called when the server sends a ping to a client.
  def on_ping(&@on_ping : String ->)
  end

  # Called when the server receives a pong from a client.
  def on_pong(&@on_pong : String ->)
  end

  # Called when the server receives a text message from a client.
  def on_message(&@on_message : String ->)
  end

  # Called when the server receives a binary message from a client.
  def on_binary(&@on_binary : Bytes ->)
  end

  # Called when the server closes a client's connection.
  def on_close(&@on_close : CloseCode, String ->)
  end

  protected def check_open
    raise IO::Error.new "Closed socket" if closed?
  end

  # Sends a message payload (message) to the client.
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

  # Sends a close frame to the client, and closes the connection.
  # The close frame may contain a body (message) that indicates the reason for closing.
  def close(code : CloseCode | Int? = nil, message = nil)
    return if closed?
    @closed = true
    @ws.close(code, message)
  end

  # Continuously receives messages and calls previously set callbacks until the websocket is closed.
  # Ping and pong messages are automatically handled.
  #
  # ```
  # # Open websocket connection
  # ws = HTTP::WebSocket.new("websocket.example.com", "/chat")
  #
  # # Set callback
  # ws.on_message do |msg|
  #   ws.send "response"
  # end
  #
  # # Start infinite loop
  # ws.run
  # ```
  def run : Nil
    loop do
      begin
        info = @ws.receive(@buffer)
      rescue
        @on_close.try &.call(CloseCode::AbnormalClosure, "")
        @closed = true
        break
      end

      case info.opcode
      when .ping?
        @current_message.write @buffer[0, info.size]
        if info.final
          message = @current_message.to_s
          @on_ping.try &.call(message)
          pong(message) unless closed?
          @current_message.clear
        end
      when .pong?
        @current_message.write @buffer[0, info.size]
        if info.final
          @on_pong.try &.call(@current_message.to_s)
          @current_message.clear
        end
      when .text?
        @current_message.write @buffer[0, info.size]
        if info.final
          @on_message.try &.call(@current_message.to_s)
          @current_message.clear
        end
      when .binary?
        @current_message.write @buffer[0, info.size]
        if info.final
          @on_binary.try &.call(@current_message.to_slice)
          @current_message.clear
        end
      when .close?
        @current_message.write @buffer[0, info.size]
        if info.final
          @current_message.rewind

          if @current_message.size >= 2
            code = @current_message.read_bytes(UInt16, IO::ByteFormat::NetworkEndian).to_i
            code = CloseCode.new(code)
          else
            code = CloseCode::NoStatusReceived
          end
          message = @current_message.gets_to_end

          @on_close.try &.call(code, message)
          close

          @current_message.clear
          break
        end
      when Protocol::Opcode::CONTINUATION
        # TODO: (asterite) I think this is good, but this case wasn't originally handled
      end
    end
  end
end

require "./web_socket/*"
