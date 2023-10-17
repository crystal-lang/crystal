{% skip_file unless flag?(:linux) %}

require "c/unistd"
require "./syscall"

{% if flag?(:interpreted) %}
  lib LibC
    fun getrandom(buf : Void*, buflen : SizeT, flags : UInt32) : LibC::SSizeT
  end

  module Crystal::System::Syscall
    GRND_NONBLOCK = 1u32

    # TODO: Implement syscall for interpreter
    def self.getrandom(buf : UInt8*, buflen : LibC::SizeT, flags : UInt32) : LibC::SSizeT
      LibC.getrandom(buf, buflen, flags)
    end
  end
{% end %}

module Crystal::System::Random
  @@initialized = false
  @@getrandom_available = false
  @@urandom : ::File?

  private def self.init
    @@initialized = true

    if has_sys_getrandom
      @@getrandom_available = true
    else
      urandom = ::File.open("/dev/urandom", "r")
      return unless urandom.info.type.character_device?

      urandom.close_on_exec = true
      urandom.read_buffering = false # don't buffer bytes
      @@urandom = urandom
    end
  end

  private def self.has_sys_getrandom
    sys_getrandom(Bytes.new(16))
    true
  rescue
    false
  end

  # Reads n random bytes using the Linux `getrandom(2)` syscall.
  def self.random_bytes(buf : Bytes) : Nil
    init unless @@initialized

    if @@getrandom_available
      getrandom(buf)
    elsif urandom = @@urandom
      urandom.read_fully(buf)
    else
      raise "Failed to access secure source to generate random bytes!"
    end
  end

  def self.next_u : UInt8
    init unless @@initialized

    if @@getrandom_available
      buf = uninitialized UInt8[1]
      getrandom(buf.to_slice)
      buf.unsafe_as(UInt8)
    elsif urandom = @@urandom
      urandom.read_byte.not_nil!
    else
      raise "Failed to access secure source to generate random bytes!"
    end
  end

  # Reads n random bytes using the Linux `getrandom(2)` syscall.
  private def self.getrandom(buf)
    # getrandom(2) may only read up to 256 bytes at once without being
    # interrupted or returning early
    chunk_size = 256

    while buf.size > 0
      if buf.size < chunk_size
        chunk_size = buf.size
      end

      read_bytes = sys_getrandom(buf[0, chunk_size])

      buf += read_bytes
    end
  end

  # Low-level wrapper for the `getrandom(2)` syscall, returns the number of
  # bytes read or the errno as a negative number if an error occurred (or the
  # syscall isn't available). The GRND_NONBLOCK=1 flag is passed as last argument,
  # so that it returns -EAGAIN if the requested entropy was not available.
  #
  # We use the kernel syscall instead of the `getrandom` C function so any
  # binary compiled for Linux will always use getrandom if the kernel is 3.17+
  # and silently fallback to read from /dev/urandom if not (so it's more
  # portable).
  private def self.sys_getrandom(buf : Bytes)
    loop do
      read_bytes = Syscall.getrandom(buf.to_unsafe, LibC::SizeT.new(buf.size), Syscall::GRND_NONBLOCK)
      if read_bytes < 0
        err = Errno.new(-read_bytes.to_i)
        if err.in?(Errno::EINTR, Errno::EAGAIN)
          ::Fiber.yield
        else
          raise RuntimeError.from_os_error("getrandom", err)
        end
      else
        return read_bytes
      end
    end
  end
end
