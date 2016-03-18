class HTTP::WebSocket
  @ws : Protocol
  @buffer : Slice(UInt8)
  @current_message : MemoryIO
  @on_message : Nil | (String ->)
  @on_close : Nil | (String ->)

  # :nodoc:
  def initialize(io : IO)
    initialize(Protocol.new(io))
  end

  # :nodoc:
  def initialize(@ws : Protocol)
    @buffer = Slice(UInt8).new(4096)
    @current_message = MemoryIO.new
  end

  # Opens a new websocket using the information provided by the URI. This will also handle the handshake
  # and will raise an exception if the handshake did not complete successfully. This method will also raise
  # an exception if the URI is missing the host and/or the path.
  #
  # Please note that the scheme will only be used to identify if SSL should be used or not. Therefore, schemes
  # apart from `wss` and `https` will be treated as the default which is `ws`.
  #
  # ```
  # WebSocket.new(URI.parse("ws://websocket.example.com/chat"))        # Creates a new WebSocket to `websocket.example.com`
  # WebSocket.new(URI.parse("wss://websocket.example.com/chat"))       # Creates a new WebSocket with SSL to `websocket.example.com`
  # WebSocket.new(URI.parse("http://websocket.example.com:8080/chat")) # Creates a new WebSocket to `websocket.example.com` on port `8080`
  # ```
  def self.new(uri : URI | String)
    new(Protocol.new(uri))
  end

  # Opens a new websocket to the target host. This will also handle the handshake
  # and will raise an exception if the handshake did not complete successfully.
  #
  # ```
  # WebSocket.new("websocket.example.com", "/chat")             # Creates a new WebSocket to `websocket.example.com`
  # WebSocket.new("websocket.example.com", "/chat", ssl = true) # Creates a new WebSocket with SSL to `ẁebsocket.example.com`
  # ```
  def self.new(host : String, path : String, port = nil, ssl = false)
    new(Protocol.new(host, path, port, ssl))
  end

  def on_message(&@on_message : String ->)
  end

  def on_close(&@on_close : String ->)
  end

  def send(message)
    @ws.send(message)
  end

  def stream(binary = true, frame_size = 1024)
    @ws.stream(binary: binary, frame_size: frame_size) do |io|
      yield io
    end
  end

  def close(message = nil)
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
      when Protocol::Opcode::TEXT
        @current_message.write @buffer[0, info.size]
        if info.final
          @on_message.try &.call(@current_message.to_s)
          @current_message.clear
        end
      when Protocol::Opcode::CLOSE
        @current_message.write @buffer[0, info.size]
        if info.final
          @on_close.try &.call(@current_message.to_s)
          @current_message.clear
          break
        end
      end
    end
  end
end

require "./web_socket/*"
