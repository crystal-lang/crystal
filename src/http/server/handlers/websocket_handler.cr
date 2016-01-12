require "base64"
require "openssl/sha1"
require "../../web_socket"

class HTTP::WebSocketHandler < HTTP::Handler
  def initialize(&@proc : WebSocketSession ->)
  end

  def call(request)
    if request.headers["Upgrade"]? == "websocket" && request.headers["Connection"]? == "Upgrade"
      key = request.headers["Sec-websocket-key"]
      accept_code = Base64.strict_encode(OpenSSL::SHA1.hash("#{key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
      response_headers = HTTP::Headers{
        "Upgrade"              => "websocket",
        "Connection"           => "Upgrade",
        "Sec-websocket-accept" => accept_code,
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
end
