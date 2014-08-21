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
    loop { handle_client(server.accept) }
  end

  def listen_fork(workers = 8)
    server = TCPServer.new(@port)
    workers.times do
      fork do
        loop { handle_client(server.accept) }
      end
    end

    puts "Ready"
    gets
  end

  private def handle_client(sock)
    io = sock
    io = ssl_sock = OpenSSL::SSL::Socket.new(io, :server, @ssl.not_nil!) if @ssl
    io = BufferedIO.new(io)

    begin
      begin
        request = HTTP::Request.from_io(io)
      rescue
        # HACK: these lines can be removed once #171 is fixed
        ssl_sock.try &.close if @ssl
        sock.close

        return
      end
      response = @handler.call(request)
      response.to_io io
      io.flush
    ensure
      ssl_sock.try &.close if @ssl
      sock.close
    end
  end

  def self.build_middleware(handlers)
    if handlers.empty?
      raise ArgumentError.new "no handlers specified"
    end

    0.upto(handlers.length - 2) do |i|
      handlers[i].next = handlers[i + 1]
    end
    handlers.first
  end
end

