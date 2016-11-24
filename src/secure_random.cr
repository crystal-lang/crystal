require "base64"

{% if flag?(:linux) %}
  require "c/unistd"
  require "c/sys/syscall"
{% end %}

# The SecureRandom module is an interface for creating cryptography secure
# random values in different formats.
#
# Examples:
# ```crystal
# SecureRandom.base64 # => "LIa9s/zWzJx49m/9zDX+VQ=="
# SecureRandom.hex    # => "c8353864ff9764a39ef74983ec0d4a38"
# SecureRandom.uuid   # => "c7ee4add-207f-411a-97b7-0d22788566d6"
# ```
#
# The implementation follows the
# [libsodium sysrandom](https://github.com/jedisct1/libsodium/blob/6fad3644b53021fb377ca1207fa6e1ac96d0b131/src/libsodium/randombytes/sysrandom/randombytes_sysrandom.c)
# implementation and uses `getrandom` on Linux (when provided by the kernel),
# then tries to read from `/dev/urandom`.
module SecureRandom
  @@initialized = false

  # Generates *n* random bytes that are encoded into Base64.
  #
  # Check `Base64#strict_encode` for details.
  #
  # ```crystal
  # SecureRandom.base64(4) # => "fK1eYg=="
  # ```
  def self.base64(n : Int = 16) : String
    Base64.strict_encode(random_bytes(n))
  end

  # URL-safe variant of `#base64`
  #
  # Check `Base64#urlsafe_encode` for details.
  #
  # ```crystal
  # SecureRandom.urlsafe_base64           # => "MAD2bw8QaBdvITCveBNCrw"
  # SecureRandom.urlsafe_base64(8, true)  # => "vvP1kcs841I="
  # SecureRandom.urlsafe_base64(16, true) # => "og2aJrELDZWSdJfVGkxNKw=="
  # ```
  def self.urlsafe_base64(n : Int = 16, padding = false) : String
    Base64.urlsafe_encode(random_bytes(n), padding)
  end

  # Generates a hexadecimal string based on *n* random bytes.
  #
  # The bytes are encoded into a string of a two-digit hexadecimal number (00-ff) per byte.
  #
  # ```crystal
  # SecureRandom.hex    # => "05f100a1123f6bdbb427698ab664ff5f"
  # SecureRandom.hex(1) # => "1a"
  # ```
  def self.hex(n : Int = 16) : String
    random_bytes(n).hexstring
  end

  # Generates a slice filled with *n* random bytes.
  #
  # ```crystal
  # SecureRandom.random_bytes    # => [145, 255, 191, 133, 132, 139, 53, 136, 93, 238, 2, 37, 138, 244, 3, 216]
  # SecureRandom.random_bytes(4) # => [217, 118, 38, 196]
  # ```
  def self.random_bytes(n : Int = 16) : Slice(UInt8)
    if n < 0
      raise ArgumentError.new "negative size: #{n}"
    end

    init unless @@initialized

    {% if flag?(:linux) %}
      if @@getrandom_available
        return getrandom(n)
      end
    {% end %}

    buf = Slice(UInt8).new(n)

    if urandom = @@urandom
      urandom.read_fully(buf)
      return buf
    end

    raise "Failed to access secure source to generate random bytes!"
  end

  private def self.init
    @@initialized = true

    {% if flag?(:linux) %}
      if getrandom(Slice(UInt8).new(16)) >= 0
        @@getrandom_available = true
        return
      end
    {% end %}

    @@urandom = urandom = File.open("/dev/urandom", "r")
    urandom.sync = true # don't buffer bytes
  end

  {% if flag?(:linux) %}
    @@getrandom_available = false

    # Reads n random bytes using the Linux `getrandom(2)` syscall.
    private def self.getrandom(n : Int)
      Slice(UInt8).new(n).tap do |buf|
        # getrandom(2) may only read up to 256 bytes at once without being
        # interrupted or returning early
        chunk_size = 256

        while buf.size > 0
          if buf.size < chunk_size
            chunk_size = buf.size
          end

          read_bytes = getrandom(buf[0, chunk_size])
          raise Errno.new("getrandom") if read_bytes == -1

          buf += read_bytes
        end
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
    private def self.getrandom(buf : Slice(UInt8))
      loop do
        read_bytes = LibC.syscall(LibC::SYS_getrandom, buf, LibC::SizeT.new(buf.size), 0)
        if read_bytes < 0 && (Errno.value == Errno::EINTR || Errno.value == Errno::EAGAIN)
          Fiber.yield
        else
          return read_bytes
        end
      end
    end
  {% end %}

  # Generates a UUID (Universally Unique Identifier)
  #
  # It generates a random v4 UUID. Check [RFC 4122 Section 4.4](https://tools.ietf.org/html/rfc4122#section-4.4)
  # for the used algorithm and its implications.
  #
  # ```crystal
  # SecureRandom.uuid # => "a4e319dd-a778-4a51-804e-66a07bc63358"
  # ```
  def self.uuid : String
    bytes = random_bytes(16)
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80

    String.new(36) do |buffer|
      buffer[8] = buffer[13] = buffer[18] = buffer[23] = 45_u8
      bytes[0, 4].hexstring(buffer + 0)
      bytes[4, 2].hexstring(buffer + 9)
      bytes[6, 2].hexstring(buffer + 14)
      bytes[8, 2].hexstring(buffer + 19)
      bytes[10, 6].hexstring(buffer + 24)
      {36, 36}
    end
  end
end
