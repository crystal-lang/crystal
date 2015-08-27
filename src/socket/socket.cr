require "./libc"

class SocketError < Exception
end

class Socket < FileDescriptorIO
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

  struct Addr
    property :family, :ip_port, :ip_address, :path

    def initialize(@family, @ip_port, @ip_address)
    end

    def initialize(@family, @path)
    end
  end

  def initialize fd, blocking = false
    super fd, blocking
    self.sync = true
  end

  protected def create_socket(family, stype, protocol = 0)
    sock = LibC.socket(LibC::Int.cast(family), stype, protocol)
    raise Errno.new("Error opening socket") if sock <= 0
    init_close_on_exec sock
    sock
  end

  # only used when SOCK_CLOEXEC doesn't exist on the current platform
  protected def init_close_on_exec fd : Int32
    {% if LibC::SOCK_CLOEXEC == 0 %}
       LibC.fcntl(fd, LibC::FCNTL::F_SETFD, LibC::FD_CLOEXEC)
    {% end %}
  end

  def inspect(io)
    io << "#<#{self.class}:fd #{@fd}>"
  end

  def send_buffer_size
    getsockopt LibC::SO_SNDBUF, 0
  end

  def send_buffer_size= val : Int32
    setsockopt LibC::SO_SNDBUF, val
    val
  end

  def recv_buffer_size
    getsockopt LibC::SO_RCVBUF, 0
  end

  def recv_buffer_size= val : Int32
    setsockopt LibC::SO_RCVBUF, val
    val
  end

  def reuse_address?
    ret = getsockopt LibC::SO_REUSEADDR, 0
    ret != 0
  end

  def reuse_address= val : Bool
    v = val ? 1 : 0
    setsockopt LibC::SO_REUSEADDR, v
    val
  end

  # returns the modified optval
  def getsockopt optname, optval, level = LibC::SOL_SOCKET
    optsize = LibC::SocklenT.cast(sizeof(typeof(optval)))
    ret = LibC.getsockopt(fd, level, optname, (pointerof(optval) as Void*), pointerof(optsize))
    raise Errno.new("getsockopt") if ret == -1
    optval
  end

  # optval is restricted to Int32 until sizeof works on variables
  def setsockopt optname, optval : Int32, level = LibC::SOL_SOCKET
    optsize = LibC::SocklenT.cast(sizeof(typeof(optval)))
    ret = LibC.setsockopt(fd, level, optname, (pointerof(optval) as Void*), optsize)
    raise Errno.new("setsockopt") if ret == -1
    ret
  end

  def self.inet_ntop(sa : LibC::SockAddrIn6)
    ip_address = GC.malloc_atomic(LibC::INET6_ADDRSTRLEN.to_u32) as UInt8*
    addr = sa.addr
    LibC.inet_ntop(LibC::AF_INET6, pointerof(addr) as Void*, ip_address, LibC::SocklenT.cast(LibC::INET6_ADDRSTRLEN))
    String.new(ip_address)
  end

  def self.inet_ntop(sa : LibC::SockAddrIn)
    ip_address = GC.malloc_atomic(LibC::INET_ADDRSTRLEN.to_u32) as UInt8*
    addr = sa.addr
    LibC.inet_ntop(LibC::AF_INET, pointerof(addr) as Void*, ip_address, LibC::SocklenT.cast(LibC::INET_ADDRSTRLEN))
    String.new(ip_address)
  end

  private def nonblocking_connect host, port, ai, timeout = nil
    loop do
      ret = LibC.connect(@fd, ai.addr, ai.addrlen)
      return nil if ret == 0 # success

      case LibC.errno
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
