require "c/sys/random"

{% if !LibC.has_method?(:getrandom) %}
  # getrandom isn't available in android before API LEVEL 28
  require "./urandom"
{% else %}
  module Crystal::System::Random
    # Reads n random bytes using the Linux `getrandom(2)` syscall.
    def self.random_bytes(buffer : Bytes) : Nil
      getrandom(buffer)
    end

    def self.next_u : UInt8
      buffer = uninitialized UInt8
      getrandom(pointerof(buffer).to_slice(1))
      buffer
    end

    # Reads n random bytes using the Linux `getrandom(2)` syscall.
    private def self.getrandom(buffer)
      # getrandom(2) may only read up to 256 bytes at once without being
      # interrupted or returning early
      chunk_size = 256

      while buffer.size > 0
        if buffer.size < chunk_size
          chunk_size = buffer.size
        end

        read_bytes = 0

        loop do
          # pass GRND_NONBLOCK flag so that it fails with EAGAIN if the requested
          # entropy was not available
          read_bytes = LibC.getrandom(buffer.to_unsafe, LibC::SizeT.new(buffer.size), LibC::GRND_NONBLOCK)
          break unless read_bytes == -1

          err = Errno.value
          raise RuntimeError.from_os_error("getrandom", err) unless err.in?(Errno::EINTR, Errno::EAGAIN)

          ::Fiber.yield
        end

        buffer += read_bytes
      end
    end
  end
{% end %}
