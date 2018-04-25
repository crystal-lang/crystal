require "base64"
require "../../web_socket"

{% if flag?(:without_openssl) %}
  require "digest/sha1"
{% else %}
  require "openssl/sha1"
{% end %}

class HTTP::WebSocketHandler
  include HTTP::Handler

  def initialize(&@proc : WebSocket, Server::Context ->)
  end

  def call(context)
    if websocket_upgrade_request? context.request
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

  private def websocket_upgrade_request?(request)
    return false unless upgrade = request.headers["Upgrade"]?
    return false unless upgrade.compare("websocket", case_insensitive: true) == 0

    request.headers.includes_word?("Connection", "Upgrade")
  end
end
