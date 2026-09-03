require "crystal/once"

module Crystal::System::Random
  @@initialized = false
  @@urandom : LibC::Int?

  @[NoInline]
  private def self.init
    Crystal.once(pointerof(@@initialized)) do
      # Directly open the urandom device without going through the event loop;
      # we never set O_NONBLOCK because it should never block (by definition)...
      # but we witnessed a case where Linux would fail with EAGAIN then never
      # trigger a ready event to epoll, blocking a fiber forever.
      fd = LibC.open("/dev/urandom", LibC::O_RDONLY | LibC::O_CLOEXEC)

      # safety check: urandom can't be a regular disk file or anything, it must
      # be a character device; if not it's a system security issue
      return unless FileDescriptor.system_info(fd).type.character_device?

      @@urandom = fd
    end
  end

  def self.random_bytes(buf : Bytes) : Nil
    init unless @@initialized

    unless fd = @@urandom
      raise "Failed to access secure source to generate random bytes!"
    end

    until buf.empty?
      case read_bytes = LibC.read(fd, buf.to_unsafe, buf.size)
      when -1
        raise ::File::Error.from_errno("Failed to read from secure source to generate random bytes!", file: "/dev/urandom")
      when 0
        raise IO::EOFError.new
      else
        buf += read_bytes
      end
    end
  end

  def self.next_u : UInt8
    buf = uninitialized UInt8[1]
    random_bytes(buf.to_slice)
    buf.to_unsafe.value
  end
end
