require "c/arpa/inet"
require "c/netdb"
require "c/netinet/in"
require "c/netinet/tcp"
require "c/sys/socket"
require "c/sys/un"

class Socket < IO::FileDescriptor
  class Error < Exception
  end

  enum Type
    STREAM    = LibC::SOCK_STREAM
    DGRAM     = LibC::SOCK_DGRAM
    RAW       = LibC::SOCK_RAW
    SEQPACKET = LibC::SOCK_SEQPACKET
  end

  enum Protocol
    IP   = LibC::IPPROTO_IP
    TCP  = LibC::IPPROTO_TCP
    UDP  = LibC::IPPROTO_UDP
    RAW  = LibC::IPPROTO_RAW
    ICMP = LibC::IPPROTO_ICMP
  end

  enum Family : LibC::SaFamilyT
    UNSPEC = LibC::AF_UNSPEC
    UNIX   = LibC::AF_UNIX
    INET   = LibC::AF_INET
    INET6  = LibC::AF_INET6
  end

  struct IPAddress
    getter family : Family
    getter address : String
    getter port : UInt16

    def initialize(@family : Family, @address : String, port : Int)
      if family != Family::INET && family != Family::INET6
        raise ArgumentError.new("Unsupported address family")
      end

      @port = port.to_u16
    end

    def initialize(sockaddr : LibC::SockaddrIn6, addrlen : LibC::SocklenT)
      case addrlen
      when LibC::SocklenT.new(sizeof(LibC::SockaddrIn))
        sockaddrin = pointerof(sockaddr).as(LibC::SockaddrIn*).value
        addr = sockaddrin.sin_addr
        @family = Family::INET
        @address = inet_ntop(family.value, pointerof(addr).as(Void*), addrlen)
      when LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))
        addr6 = sockaddr.sin6_addr
        @family = Family::INET6
        @address = inet_ntop(family.value, pointerof(addr6).as(Void*), addrlen)
      else
        raise ArgumentError.new("Unsupported address family")
      end
      @port = LibC.htons(sockaddr.sin6_port).to_u16
    end

    def sockaddr
      sockaddrin6 = LibC::SockaddrIn6.new
      sockaddrin6.sin6_family = LibC::SaFamilyT.new(family.value)

      case family
      when Family::INET
        sockaddrin = pointerof(sockaddrin6).as(LibC::SockaddrIn*).value
        addr = sockaddrin.sin_addr
        LibC.inet_pton(family.value, address, pointerof(addr).as(Void*))
        sockaddrin.sin_addr = addr
        sockaddrin6 = pointerof(sockaddrin).as(LibC::SockaddrIn6*).value
      when Family::INET6
        addr6 = sockaddrin6.sin6_addr
        LibC.inet_pton(family.value, address, pointerof(addr6).as(Void*))
        sockaddrin6.sin6_addr = addr6
      end

      sockaddrin6.sin6_port = LibC.ntohs(port).to_i16
      sockaddrin6
    end

    def addrlen
      case family
      when Family::INET  then LibC::SocklenT.new(sizeof(LibC::SockaddrIn))
      when Family::INET6 then LibC::SocklenT.new(sizeof(LibC::SockaddrIn6))
      else                    LibC::SocklenT.new(0)
      end
    end

    def to_s(io)
      io << address << ":" << port
    end

    private def inet_ntop(af : Int, src : Void*, len : LibC::SocklenT)
      dest = GC.malloc_atomic(addrlen.to_u32).as(UInt8*)
      if LibC.inet_ntop(af, src, dest, len).null?
        raise Errno.new("Failed to convert IP address")
      end
      String.new(dest)
    end
  end

  struct UNIXAddress
    getter path : String

    def initialize(@path : String)
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
    {% unless LibC.constants.includes?("SOCK_CLOEXEC".id) %}
      LibC.fcntl(fd, LibC::F_SETFD, LibC::FD_CLOEXEC)
    {% end %}
  end

  # Calls shutdown(2) with SHUT_RD
  def close_read
    shutdown LibC::SHUT_RD
  end

  # Calls shutdown(2) with SHUT_WR
  def close_write
    shutdown LibC::SHUT_WR
  end

  private def shutdown(how)
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
    ret.l_onoff == 0 ? nil : ret.l_linger
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
      v.l_onoff = 1
      v.l_linger = val
    when nil
      v.l_onoff = 0
    end

    setsockopt LibC::SO_LINGER, v
    val
  end

  # returns the modified optval
  def getsockopt(optname, optval, level = LibC::SOL_SOCKET)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))
    ret = LibC.getsockopt(fd, level, optname, (pointerof(optval).as(Void*)), pointerof(optsize))
    raise Errno.new("getsockopt") if ret == -1
    optval
  end

  # optval is restricted to Int32 until sizeof works on variables
  def setsockopt(optname, optval, level = LibC::SOL_SOCKET)
    optsize = LibC::SocklenT.new(sizeof(typeof(optval)))
    ret = LibC.setsockopt(fd, level, optname, (pointerof(optval).as(Void*)), optsize)
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

  private def nonblocking_connect(host, port, addrinfo, timeout = nil)
    loop do
      ret =
        {% if flag?(:freebsd) || flag?(:openbsd) %}
          LibC.connect(@fd, addrinfo.ai_addr.as(LibC::Sockaddr*), addrinfo.ai_addrlen)
        {% else %}
          LibC.connect(@fd, addrinfo.ai_addr, addrinfo.ai_addrlen)
        {% end %}
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

  # Returns true if the string represents a valid IPv4 or IPv6 address.
  def self.ip?(string : String)
    addr = LibC::In6Addr.new
    ptr = pointerof(addr).as(Void*)
    LibC.inet_pton(LibC::AF_INET, string, ptr) > 0 || LibC.inet_pton(LibC::AF_INET6, string, ptr) > 0
  end
end

require "./socket/*"
