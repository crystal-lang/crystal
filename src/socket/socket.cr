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

  struct Addr
    property :family, :ip_port, :ip_address, :path

    def initialize(@family, @ip_port, @ip_address)
    end

    def initialize(@family, @path)
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

  def self.inet_ntop(sa : LibC::SockAddrIn6)
    ip_address = GC.malloc_atomic(LibC::INET6_ADDRSTRLEN.to_u32) as UInt8*
    addr = sa.addr
    if LibC.inet_ntop(LibC::AF_INET6, pointerof(addr) as Void*, ip_address, LibC::INET6_ADDRSTRLEN).null?
      raise Errno.new("inet_ntop")
    end
    String.new(ip_address)
  end

  def self.inet_ntop(sa : LibC::SockAddrIn)
    ip_address = GC.malloc_atomic(LibC::INET_ADDRSTRLEN.to_u32) as UInt8*
    addr = sa.addr
    if LibC.inet_ntop(LibC::AF_INET, pointerof(addr) as Void*, ip_address, LibC::INET_ADDRSTRLEN).null?
      raise Errno.new("inet_ntop")
    end
    String.new(ip_address)
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
