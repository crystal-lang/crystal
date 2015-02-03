require "uv"
require "fiber"

class TCPSocket
  include IO

  def initialize(host, port)
    LibUV.tcp_init(UV::Loop::DEFAULT, out @tcp)
    @tcp.data = self as Void*
    @current_buf :: LibUV::Buf
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

  def write(slice : Slice(UInt8), count)
    write_req :: LibUV::Write
    write_req.data = Fiber.current as Void*
    buf :: LibUV::Buf
    buf.base = slice.pointer(slice.length) as Void*
    buf.len = LibC::SizeT.cast(slice.length)

    LibUV.write(pointerof(write_req), stream, pointerof(buf), 1_u32, ->(write, status) {
      fiber = write.value.data as Fiber
      write.value.data = Pointer(Void).new(status.to_u64)
      fiber.resume
    })

    Fiber.yield
  end

  def read(slice : Slice(UInt8), count)
    @reading = true
    @current_buf.len = LibC::SizeT.cast(Math.min(slice.length, count))
    @current_buf.base = slice.pointer(@current_buf.len) as Void*
    @current_fiber = Fiber.current

    LibUV.read_start(stream,
      ->(handle, size, buf) {
        this = handle.value.data as TCPSocket
        buf.value = this.@current_buf
      },
      ->(stream, nread, buf) {
        this = stream.value.data as TCPSocket
        this.set_nread nread
        this.@current_fiber.not_nil!.resume

        unless this.@reading
          LibUV.read_stop(stream)
        end
      })

    Fiber.yield
    @reading = false
    @nread.not_nil!
  end

  def close
  end

  def set_nread(n)
    @nread = n
  end

  private def stream
    pointerof(@tcp) as LibUV::Stream*
  end
end
