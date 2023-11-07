require "base64"
require "http/web_socket"

# A handler which adds websocket functionality to an `HTTP::Server`.
#
# NOTE: To use `WebSocketHandler`, you must explicitly import it with `require "http"`
#
# When a request can be upgraded, the associated `HTTP::WebSocket` and
# `HTTP::Server::Context` will be yielded to the block. For example:
#
# ```
# ws_handler = HTTP::WebSocketHandler.new do |ws, ctx|
#   ws.on_ping { ws.pong ctx.request.path }
# end
# server = HTTP::Server.new [ws_handler]
# ```
class HTTP::WebSocketHandler
  include HTTP::Handler

  def initialize(&@proc : WebSocket, Server::Context ->)
  end

  def call(context) : Nil
    unless websocket_upgrade_request? context.request
      return call_next context
    end

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
    end
  end

  private def websocket_upgrade_request?(request)
    return false unless upgrade = request.headers["Upgrade"]?
    return false unless upgrade.compare("websocket", case_insensitive: true) == 0

    request.headers.includes_word?("Connection", "Upgrade")
  end
end
