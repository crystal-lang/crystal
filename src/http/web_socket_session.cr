class HTTP::WebSocketSession
  def initialize(io : IO)
    initialize(WebSocket.new(io))
  end

  def initialize(@ws : WebSocket)
    @buffer = Slice(UInt8).new(4096)
    @current_message = MemoryIO.new
  end

  def self.new(uri : URI | String)
    new(WebSocket.new(uri))
  end

  def self.new(host : String, path : String, port = nil, ssl = false)
    new(WebSocket.new(host, path, port, ssl))
  end

  def on_message(&@on_message : String ->)
  end

  def on_close(&@on_close : String ->)
  end

  def send(message)
    @ws.send(message)
  end

  def run
    loop do
      info = @ws.receive(@buffer)
      case info.opcode
      when WebSocket::Opcode::TEXT
        @current_message.write @buffer[0, info.size]
        if info.final
          if handler = @on_message
            handler.call(@current_message.to_s)
          end
          @current_message.clear
        end
      when WebSocket::Opcode::CLOSE
        @current_message.write @buffer[0, info.size]
        if info.final
          if handler = @on_close
            handler.call(@current_message.to_s)
          end
          @current_message.clear
          break
        end
      end
    end
  end
end
