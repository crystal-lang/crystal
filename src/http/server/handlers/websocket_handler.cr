require "base64"
require "../../web_socket"

{% if flag?(:without_openssl) %}
  require "digest/sha1"
{% else %}
  require "openssl/sha1"
{% end %}

class HTTP::WebSocketHandler < HTTP::Handler
  def initialize(&@proc : WebSocket, Server::Context ->)
  end

  def call(context)
    if context.request.headers["Upgrade"]? == "websocket" && context.request.headers.includes_word?("Connection", "Upgrade")
      key = context.request.headers["Sec-Websocket-Key"]

      accept_code =
        {% if flag?(:without_openssl) %}
          Digest::SHA1.base64digest("#{key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
        {% else %}
          Base64.strict_encode(OpenSSL::SHA1.hash("#{key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
        {% end %}

      response = context.response
      response.status_code = 101
      response.headers["Upgrade"] = "websocket"
      response.headers["Connection"] = "Upgrade"
      response.headers["Sec-Websocket-Accept"] = accept_code
      response.upgrade do |io|
        ws_session = WebSocket.new(io)
        @proc.call(ws_session, context)
        ws_session.run
        io.close
      end
    else
      call_next(context)
    end
  end
end
