{% skip_file if flag?(:win32) %}

require "base64"
require "http/web_socket"

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
      response = context.response

      version = context.request.headers["Sec-WebSocket-Version"]?
      unless version == WebSocket::Protocol::VERSION
        response.status = :upgrade_required
        response.headers["Sec-WebSocket-Version"] = WebSocket::Protocol::VERSION
        return
      end

      key = context.request.headers["Sec-WebSocket-Key"]?

      unless key
        response.respond_with_status(:bad_request)
        return
      end

      accept_code = WebSocket::Protocol.key_challenge(key)

      response.status = :switching_protocols
      response.headers["Upgrade"] = "websocket"
      response.headers["Connection"] = "Upgrade"
      response.headers["Sec-WebSocket-Accept"] = accept_code
      response.upgrade do |io|
        ws_session = WebSocket.new(io, sync_close: false)
        @proc.call(ws_session, context)
        ws_session.run
      ensure
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
