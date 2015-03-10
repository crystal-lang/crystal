require "openssl"
require "socket"
require "../common"

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

require "./handlers/*"

class HTTP::Server
  property ssl

  @wants_close = false

  def initialize(@port, &@handler : Request -> Response)
  end

  def initialize(@port, handlers : Array(HTTP::Handler))
    @handler = HTTP::Server.build_middleware handlers
  end

  def initialize(@port, @handler)
  end

  def listen
    server = TCPServer.new(@port)
    until @wants_close
      spawn handle_client(server.accept)
    end
  end

  def listen_fork(workers = 8)
    server = TCPServer.new(@port)
    workers.times do
      fork do
        loop { spawn handle_client(server.accept) }
      end
    end

    puts "Ready"
    gets
  end

  def close
    @wants_close = true
  end

  private def handle_client(sock)
    io = sock
    io = ssl_sock = OpenSSL::SSL::Socket.new(io, :server, @ssl.not_nil!) if @ssl
    io = BufferedIO.new(io)

    begin
      until @wants_close
        begin
          request = HTTP::Request.from_io(io)
        rescue
          # HACK: these lines can be removed once #171 is fixed
          ssl_sock.try &.close if @ssl
          sock.close

          return
        end
        break unless request
        response = @handler.call(request)
        response.headers["Connection"] = "keep-alive" if request.keep_alive?
        response.to_io io
        io.flush

        if upgrade_handler = response.upgrade_handler
          return upgrade_handler.call(io)
        end

        break unless request.keep_alive?
      end
    ensure
      ssl_sock.try &.close if @ssl
      sock.close
    end
  end

  def self.build_middleware(handlers, last_handler = nil : Request -> Response)
    if handlers.empty?
      raise ArgumentError.new "no handlers specified"
    end

    0.upto(handlers.length - 2) do |i|
      handlers[i].next = handlers[i + 1]
    end

    if last_handler
      handlers.last.next = last_handler
    end

    handlers.first
  end
end

