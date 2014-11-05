require "base64"
require "openssl/sha1"
require "net/http/websocket"

class HTTP::WebSocketHandler < HTTP::Handler
  def initialize(&@proc : WebSocketSession ->)
  end

  def call(request)
    if request.headers["Upgrade"]? == "websocket" && request.headers["Connection"]? == "Upgrade"
      key = request.headers["Sec-WebSocket-Key"]
      accept_code = Base64.strict_encode64(OpenSSL::SHA1.hash("#{key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
      response_headers = HTTP::Headers {
        "Upgrade" => "websocket",
        "Connection" => "Upgrade"
        "Sec-WebSocket-Accept" => accept_code
      }
      response = Response.new(101, headers: response_headers)
      response.upgrade_handler = ->(io : IO) do
        ws_session = WebSocketSession.new(io)
        @proc.call(ws_session)
        ws_session.run
      end
      response
    else
      call_next(request)
    end
  end

  class WebSocketSession
    def initialize(io)
      @ws = WebSocket.new(io)
      @buffer = Slice(UInt8).new(4096)
      @current_message = StringIO.new
    end

    def onmessage(&@onmessage : String ->)
    end

    def run
      loop do
        info = @ws.receive(@buffer)
        case info.type
        when :text
          @current_message.write(@buffer, info.length)
          if info.final?
            if handler = @onmessage
              handler.call(@current_message.to_s)
            end
            @current_message.clear
          end
        end
      end
    end
  end

end
