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
  property ssl

  def initialize(@port, &@handler : Request -> Response)
  end

  def initialize(@port, handlers : Array(HTTP::Handler))
    @handler = HTTP::Server.build_middleware handlers
  end

  def initialize(@port, @handler)
  end

  def listen
    server = TCPServer.new(@port)

    while true
      io = sock = server.accept
      io = ssl_sock = @ssl.not_nil!.new_server(io) if @ssl
      io = BufferedIO.new(io)

      begin
        begin
          request = HTTP::Request.from_io(io)
        rescue
          # HACK: these lines can be removed once #171 is fixed
          ssl_sock.try &.close if @ssl
          sock.close

          next
        end
        response = @handler.call(request)
        response.to_io io
        io.flush
      ensure
        ssl_sock.try &.close if @ssl
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

