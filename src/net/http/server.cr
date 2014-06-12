abstract class HTTP::Handler
  property :next

  def call_next(request)
    if next_handler = @next
      next_handler.call(request)
    else
      HTTP::Response.not_found
    end
  end
end

class HTTP::Server
  def initialize(@port, &@handler : Request -> Response)
  end

  def initialize(@port handlers : Array(HTTP::Handler))
    @handler = HTTP::Server.build_middleware handlers
  end

  def initialize(@port, @handler)
  end

  def listen
    server = TCPServer.new(@port)

    while true
      sock = server.accept
      buffered_sock = BufferedIO.new(sock)

      begin
        begin
          request = HTTP::Request.from_io(buffered_sock)
        rescue
          next
        end
        response = @handler.call(request)
        response.to_io buffered_sock
        buffered_sock.flush
      ensure
        sock.close
      end
    end
  end

  def self.build_middleware(handlers)
    0.upto(handlers.length - 2) do |i|
      handlers[i].next = handlers[i + 1]
    end
    handlers.first
  end
end

