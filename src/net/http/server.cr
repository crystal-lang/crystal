abstract class HTTP::Handler
  property :next
end

class HTTP::Server
  def initialize(@port, &@handler : Request -> Response)
  end

  def initialize(@port, @handler)
  end

  def listen
    server = TCPServer.new(@port)

    while true
      sock = server.accept
      begin
        begin
          request = HTTP::Request.from_io(sock)
        rescue
          next
        end
        response = @handler.call(request)
        response.to_io sock
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

