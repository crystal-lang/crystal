require "./tcp_socket"

class TCPServer < TCPSocket
  def initialize(host, port, backlog = 128)
    LibUV.tcp_init(UV::Loop::DEFAULT, out @tcp)
    @tcp.data = self as Void*
    @current_buf = LibUV::Buf.new
    @reading = false
    @client_queue = [] of TCPSocket
    @acceptors = [] of Fiber

    getaddrinfo(host, port, nil, LibC::SOCK_STREAM, LibC::IPPROTO_TCP) do |ai|
      connect :: LibUV::Connect
      connect.data = Fiber.current as Void*

      if LibUV.tcp_bind(pointerof(@tcp), (ai.addr as LibC::SockAddr*), 0) == 0
        break
      else
        raise raise SocketError.new("Error binding TCP server at #{host}#{port}") unless ai.next
      end
    end

    LibUV.listen(stream, backlog, ->(server, status) {
      (server.value.data as TCPServer).new_connection
    })
  end

  protected def new_connection
    @client_queue << TCPSocket.new(stream)
    if fiber = @acceptors.shift?
      fiber.resume
    end
  end

  def accept
    while @client_queue.empty?
      @acceptors << Fiber.current
      Scheduler.reschedule
    end
    @client_queue.shift
  end
end
