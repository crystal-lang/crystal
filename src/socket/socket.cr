require "./libc"

class Socket < IO::FileDescriptor
  class Error < Exception
  end

  enum Type
    STREAM = LibC::SOCK_STREAM
    DGRAM  = LibC::SOCK_DGRAM
    RAW    = LibC::SOCK_RAW
  end

  enum Protocol
    IP  = LibC::IPPROTO_IP
    TCP = LibC::IPPROTO_TCP
    UDP = LibC::IPPROTO_UDP
    RAW = LibC::IPPROTO_RAW
  end

  enum Family : LibC::AddressFamilyType
    UNSPEC = LibC::AF_UNSPEC
    UNIX   = LibC::AF_UNIX
    INET   = LibC::AF_INET
    INET6  = LibC::AF_INET6
  end

  struct IPAddress
    getter family : Family
    getter address : String
    getter port : UInt16

    def initialize(family : Family, address : String, port : Int)
      if family != Family::INET && family != Family::INET6
        raise ArgumentError.new("Unsupported address family")
      end

      @family = family
      @address = address
      @port = port.to_u16
    end

    def initialize(sockaddr : LibC::SockAddrIn6, addrlen : LibC::SocklenT)
      case addrlen
      when LibC::SocklenT.new(sizeof(LibC::SockAddrIn))
        sockaddrin = (pointerof(sockaddr) as LibC::SockAddrIn*).value
        addr = sockaddrin.addr
        @family = Family::INET
        @address = inet_ntop(family.value, pointerof(addr) as Void*, addrlen)
      when LibC::SocklenT.new(sizeof(LibC::SockAddrIn6))
        addr6 = sockaddr.addr
        @family = Family::INET6
        @address = inet_ntop(family.value, pointerof(addr6) as Void*, addrlen)
      else
        raise ArgumentError.new("Unsupported address family")
      end
      @port = LibC.htons(sockaddr.port).to_u16
    end

    def sockaddr
      sockaddrin6 = LibC::SockAddrIn6.new
      sockaddrin6.family = family.value.to_u8

      case family
      when Family::INET
        sockaddrin = (pointerof(sockaddrin6) as LibC::SockAddrIn*).value
        addr = sockaddrin.addr
        LibC.inet_pton(family.value, address, pointerof(addr) as Void*)
        sockaddrin.addr = addr
        sockaddrin6 = (pointerof(sockaddrin) as LibC::SockAddrIn6*).value
      when Family::INET6
        addr6 = sockaddrin6.addr
        LibC.inet_pton(family.value, address, pointerof(addr6) as Void*)
        sockaddrin6.addr = addr6
      end

      sockaddrin6.port = LibC.ntohs(port).to_i16
      sockaddrin6
    end

    def addrlen
      case family
      when Family::INET  then LibC::SocklenT.new(sizeof(LibC::SockAddrIn))
      when Family::INET6 then LibC::SocklenT.new(sizeof(LibC::SockAddrIn6))
      else                    LibC::SocklenT.new(0)
      end
    end

    def to_s(io)
      io << address << ":" << port
    end

    private def inet_ntop(af : Int, src : Void*, len : LibC::SocklenT)
      dest = GC.malloc_atomic(addrlen.to_u32) as UInt8*
      if LibC.inet_ntop(af, src, dest, len).null?
        raise Errno.new("Failed to convert IP address")
      end
      String.new(dest)
    end
  end

  struct UNIXAddress
    getter path : String

    def initialize(path)
      @path = path
    end

    def family
      Family::UNIX
    end

    def to_s(io)
      path.to_s(io)
    end
  end

  def initialize(fd, blocking = false)
    super fd, blocking
    self.sync = true
  end

  protected def create_socket(family, stype, protocol = 0)
    sock = LibC.socket(family, stype, protocol)
    raise Errno.new("Error opening socket") if sock <= 0
    init_close_on_exec sock
    sock
  end

  # only used when SOCK_CLOEXEC doesn't exist on the current platform
  protected def init_close_on_exec(fd : Int32)
    {% if LibC::SOCK_CLOEXEC == 0 %}
       LibC.fcntl(fd, LibC::FCNTL::F_SETFD, LibC::FD_CLOEXEC)
    {% end %}
  end

  # Calls shutdown(2) with SHUT_READ
  def close_read
    shutdown LibC::Shutdown::READ
  end

  # Calls shutdown(2) with SHUT_WRITE
  def close_write
    shutdown LibC::Shutdown::WRITE
  end

  private def shutdown(how : LibC::Shutdown)
    if LibC.shutdown(@fd, how) != 0
      raise Errno.new("shutdown #{how}")
    end
  end

  def inspect(io)
    io << "#<#{self.class}:fd #{@fd}>"
  end

  def send_buffer_size
    getsockopt LibC::SO_SNDBUF, 0
  end

  def send_buffer_size=(val : Int32)
    setsockopt LibC::SO_SNDBUF, val
    val
  end

  def recv_buffer_size
    getsockopt LibC::SO_RCVBUF, 0
  end

  def recv_buffer_size=(val : Int32)
    setsockopt LibC::SO_RCVBUF, val
    val
  end

  def reuse_address?
    getsockopt_bool LibC::SO_REUSEADDR
  end

  def reuse_address=(val : Bool)
    setsockopt_bool LibC::SO_REUSEADDR, val
  end

  def broadcast?
    getsockopt_bool LibC::SO_BROADCAST
  end

  def broadcast=(val : Bool)
    setsockopt_bool LibC::SO_BROADCAST, val
  end

  def keepalive?
    getsockopt_bool LibC::SO_KEEPALIVE
  end

  def keepalive=(val : Bool)
    setsockopt_bool LibC::SO_KEEPALIVE, val
  end

  def linger
    v = LibC::Linger.new
    ret = getsockopt LibC::SO_LINGER, v
    case ret.on
    when 1
      return ret.secs
    when 0
      return nil
    else
      raise "unknown linger return #{ret.inspect}"
    end
    ret
  end

  # WARNING: The behavior of SO_LINGER is platform specific.  Bad things may happen especially with nonblocking sockets.
  # See https://www.nybek.com/blog/2015/04/29/so_linger-on-non-blocking-sockets/ for more information.
  #
  # nil => disable SO_LINGER
  # Int => enable SO_LINGER and set timeout to Int seconds.
  #
  #   0 => abort on close (socket buffer is discarded and RST sent to peer).  Depends on platform and whether shutdown() was called first.
  # >=1 => abort after Num seconds on close.  Linux and Cygwin may block on close.
  def linger=(val : Int?)
    v = LibC::Linger.new
    case val
    when Int
      v.on = 1
      v.secs = val
    when nil
      v.on = 0
    end

    setsockopt LibC::SO_LINGER, v
    val
  end

  # returns the modified optval
  def getsockopt(optname, optval, level = LibC::SOL_SOCKET)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))
    ret = LibC.getsockopt(fd, level, optname, (pointerof(optval) as Void*), pointerof(optsize))
    raise Errno.new("getsockopt") if ret == -1
    optval
  end

  # optval is restricted to Int32 until sizeof works on variables
  def setsockopt(optname, optval, level = LibC::SOL_SOCKET)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))
    ret = LibC.setsockopt(fd, level, optname, (pointerof(optval) as Void*), optsize)
    raise Errno.new("setsockopt") if ret == -1
    ret
  end

  private def getsockopt_bool(optname, level = LibC::SOL_SOCKET)
    ret = getsockopt optname, 0, level
    ret != 0
  end

  private def setsockopt_bool(optname, optval : Bool, level = LibC::SOL_SOCKET)
    v = optval ? 1 : 0
    ret = setsockopt optname, v, level
    optval
  end

  private def nonblocking_connect(host, port, ai, timeout = nil)
    loop do
      ret = LibC.connect(@fd, ai.addr, ai.addrlen)
      return nil if ret == 0 # success

      case Errno.value
      when Errno::EISCONN
        return nil # success
      when Errno::EINPROGRESS, Errno::EALREADY
        wait_writable(msg: "connect timed out", timeout: timeout) { |err| return err }
      else
        return Errno.new("Error connecting to '#{host}:#{port}'")
      end
    end
  end
end

require "./*"
