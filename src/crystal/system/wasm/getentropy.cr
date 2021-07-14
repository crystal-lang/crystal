require "c/unistd"

lib LibC
  fun getentropy(buffer : Void*, len : SizeT) : Int
end

module Crystal::System::Random
  @@initialized = false
  @@getentropy_available = false
  @@urandom : ::File?

  private def self.init
    @@initialized = true

    if LibC.getentropy(Bytes.new(16), 16) >= 0
      @@getentropy_available = true
    else
      urandom = ::File.open("/dev/urandom", "r")
      return unless urandom.info.type.character_device?

      urandom.close_on_exec = true
      urandom.sync = true # don't buffer bytes
      @@urandom = urandom
    end
  end

  # Reads n random bytes using the Linux `getentropy(2)` syscall.
  def self.random_bytes(buf : Bytes) : Nil
    init unless @@initialized

    if @@getentropy_available
      getentropy(buf)
    elsif urandom = @@urandom
      urandom.read_fully(buf)
    else
      raise "Failed to access secure source to generate random bytes!"
    end
  end

  def self.next_u : UInt8
    init unless @@initialized

    if @@getentropy_available
      buf = uninitialized UInt8[1]
      getentropy(buf.to_slice)
      buf.unsafe_as(UInt8)
    elsif urandom = @@urandom
      urandom.read_byte.not_nil!
    else
      raise "Failed to access secure source to generate random bytes!"
    end
  end

  # Reads n random bytes using the Linux `getentropy(2)` syscall.
  private def self.getentropy(buf)
    # getentropy(2) may only read up to 256 bytes at once without being
    # interrupted or returning early
    chunk_size = 256

    while buf.size > 0
      if buf.size < chunk_size
        chunk_size = buf.size
      end

      ret = LibC.getentropy(buf, chunk_size)

      raise RuntimeError.from_errno("getentropy") if ret == -1

      buf += chunk_size
    end
  end
end
