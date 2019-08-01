class HTTP::WebSocket
  getter? closed = false
  getter! close_reason : String

  enum Opcode : UInt8
    CONTINUATION = 0x0
    TEXT         = 0x1
    BINARY       = 0x2
    CLOSE        = 0x8
    PING         = 0x9
    PONG         = 0xA
  end

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

  struct Message
    getter opcode

    def initialize(@opcode : Opcode, @data : String | Bytes)
    end

    def text
      @data.as(String)
    end

    def binary
      @data.as(Bytes)
    end
  end

  private def handle_opcode(message)
    case message.opcode
    when .close?
      close(message.text) unless closed?
      @close_reason = message.text
    when .ping?
      pong(message.text) unless closed?
    end

    if message.opcode.text? || message.opcode.binary?
      return true
    else
      return false
    end
  end

  # Waits until a full String or Bytes message is received on the socket and returns it.
  # The data can be accessed in the `message` property of the returned struct.
  #
  # This method will respond to PING frames with PONG and close when a CLOSE frame is received.
  # Use `#receive_raw` if you don't want that.
  def receive
    loop do
      data = receive_raw

      if handle_opcode(receive_raw)
        return data
      end
    end
  end

  def receive_raw!
    loop do
      begin
        info = @ws.receive(@buffer)
      rescue IO::EOFError
        return Message.new(:close, "")
        break
      end

      @current_message.write @buffer[0, info.size]
      next unless info.final

      case info.opcode
      when .text?
        message = Message.new(:text, @current_message.to_s)
      when .binary?
        message = Message.new(:binary, @current_message.to_slice)
      when .close?
        message = Message.new(:close, @current_message.to_s)
      when .ping?
        message = Message.new(:ping, @current_message.to_s)
      when .pong?
        message = Message.new(:pong, @current_message.to_s)
      end

      @current_message.clear
      return message.not_nil!
    end
  end

  def run
    loop do
      message = receive_raw!

      case message.opcode
      when .ping?
        @on_ping.try &.call(message.text)
      when .pong?
        @on_pong.try &.call(message.text)
      when .text?
        @on_message.try &.call(message.text)
      when .binary?
        @on_binary.try &.call(message.binary)
      when .close?
        @on_close.try &.call(message.text)
        break
      end

      handle_opcode(message)
    end
  end
end

require "./web_socket/*"
