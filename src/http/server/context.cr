require "../request"
require "./response"

class HTTP::Server
  # Instances of this class are passed to an `HTTP::Server` handler.
  class Context
    # The `HTTP::Request` to process.
    getter request : Request

    # The `HTTP::Server::Response` to configure and write to.
    getter response : Response

    # The network address that sent the request to an HTTP server.
    #
    # Middlewares can overwrite this value.
    #
    # Example:
    #
    # ```
    # class ForwarderHandler
    #   include HTTP::Handler
    #
    #   def call(context)
    #     if ip = context.request.headers["X-Real-IP"]? # When using a reverse proxy that guarantees this field.
    #       context.remote_address = Socket::IPAddress.new(ip, 0)
    #     end
    #     call_next(context)
    #   end
    # end
    #
    # server = HTTP::Server.new([ForwarderHandler.new, HTTP::LogHandler.new])
    # ```
    property remote_address : Socket::Address?

    # The network address of the HTTP server.
    #
    # Middlewares can overwrite this value.
    property local_address : Socket::Address?

    # :nodoc:
    def initialize(@request : Request, @response : Response, *, @remote_address : Socket::Address? = nil, @local_address : Socket::Address? = nil)
    end
  end
end
