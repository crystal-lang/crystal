require "uv"
require "fiber"

class TCPSocket < UV::Stream

  def initialize(host, port)
    LibUV.tcp_init(UV::Loop::DEFAULT, out @tcp)
    @tcp.data = self as Void*
    @current_buf = LibUV::Buf.new
    @reading = false

    getaddrinfo(host, port, nil, LibC::SOCK_STREAM, LibC::IPPROTO_TCP) do |ai|
      connect :: LibUV::Connect
      connect.data = Fiber.current as Void*

      LibUV.tcp_connect(pointerof(connect), pointerof(@tcp), (ai.addr as LibC::SockAddr*), ->(conn, status) {
        fiber = conn.value.data as Fiber
        conn.value.data = Pointer(Void).new(status.to_u64)
        fiber.resume
      })

      Fiber.yield

      break if connect.data.nil?
      unless ai.next
        raise "Could not connect"
      end
    end
  end

  def initialize(server : Stream*)
    LibUV.tcp_init(UV::Loop::DEFAULT, out @tcp)
    LibUV.accept(server, stream)
    @tcp.data = self as Void*
    @current_buf :: LibUV::Buf
    @reading = false
  end

  private def getaddrinfo(host, port, family, socktype, protocol = LibC::IPPROTO_IP)
    hints = LibC::Addrinfo.new
    hints.family = (family || LibC::AF_UNSPEC).to_i32
    hints.socktype = socktype
    hints.protocol = protocol
    hints.flags = 0

    request :: LibUV::GetAddrInfoReq
    request.data = Fiber.current as Void*

    LibUV.getaddrinfo(UV::Loop::DEFAULT, pointerof(request), ->(req, status, res) {
      fiber = req.value.data as Fiber
      if status == 0
        req.value.data = res as Void*
      else
        req.value.data = Pointer(Void).new(0_u64)
      end
      fiber.resume
    }, host, port.to_s, pointerof(hints))
    Fiber.yield

    addrinfo = request.data as LibC::Addrinfo*
    raise SocketError.new("getaddrinfo: ??") if addrinfo.nil?

    begin
      current_addrinfo = addrinfo
      while current_addrinfo
        yield current_addrinfo.value
        current_addrinfo = current_addrinfo.value.next
      end
    ensure
      LibUV.freeaddrinfo(addrinfo)
    end
  end

  def set_nread(n)
    @nread = n
  end

  private def stream
    pointerof(@tcp) as LibUV::Stream*
  end
end
