{% skip_file() unless flag?(:linux) %}

require "c/unistd"
require "c/sys/syscall"

module Crystal::System::Random
  @@initialized = false
  @@getrandom_available = false
  @@urandom : File?

  private def self.init
    @@initialized = true

    if sys_getrandom(Bytes.new(16)) >= 0
      @@getrandom_available = true
    else
      urandom = File.open("/dev/urandom", "r")
      return unless urandom.stat.chardev?

      urandom.close_on_exec = true
      urandom.sync = true # don't buffer bytes
      @@urandom = urandom
    end
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
      buf.to_unsafe.as(UInt8*).value
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
      raise Errno.new("getrandom") if read_bytes == -1

      buf += read_bytes
    end
  end

  # Low-level wrapper for the `getrandom(2)` syscall, returns the number of
  # bytes read or `-1` if an error occured (or the syscall isn't available)
  # and sets `Errno.value`.
  #
  # We use the kernel syscall instead of the `getrandom` C function so any
  # binary compiled for Linux will always use getrandom if the kernel is 3.17+
  # and silently fallback to read from /dev/urandom if not (so it's more
  # portable).
  private def self.sys_getrandom(buf : Bytes)
    loop do
      read_bytes = LibC.syscall(LibC::SYS_getrandom, buf, LibC::SizeT.new(buf.size), 0)
      if read_bytes < 0 && (Errno.value == Errno::EINTR || Errno.value == Errno::EAGAIN)
        Fiber.yield
      else
        return read_bytes
      end
    end
  end
end
