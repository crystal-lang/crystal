require "crystal/system/random"

# `Random::Secure` provides a [cryptographically secure pseudorandom number generator (CSRPNG)](https://en.wikipedia.org/wiki/Cryptographically_secure_pseudorandom_number_generator)
# for cryptography and secure usages such as generating secret keys, or seeding a pseudorandom number generator (PRNG).
#
# ```
# Random::Secure.rand(6)            # => 4
# [1, 5, 6].shuffle(Random::Secure) # => [6, 1, 5]
# ```
#
# It uses a secure source provided by the operating system.
# On OpenBSD, it uses [`arc4random`](https://man.openbsd.org/arc4random),
# on Linux [`getrandom`](http://man7.org/linux/man-pages/man2/getrandom.2.html) (if the kernel supports it),
# on Windows [`RtlGenRandom`](https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-rtlgenrandom),
# and falls back to reading from `/dev/urandom` on UNIX systems.
#
# For generating *high quality* random numbers, a pseudorandom number generator
# (PRNG) such as `Random::PCG32` should be used instead, or preferably one with
# more state (e.g. `xoshiro256**`). These number generators are much faster
# than `Random::Secure`.
module Random::Secure
  extend Random

  def self.next_u
    Crystal::System::Random.next_u
  end

  def self.random_bytes(buf : Bytes)
    Crystal::System::Random.random_bytes(buf)
  end

  {% for type in [UInt8, UInt16, UInt32, UInt64] %}
    # Generates a random integer of a given type. The number of bytes to
    # generate can be limited; by default it will generate as many bytes as
    # needed to fill the integer size.
    private def self.rand_type(type : {{type}}.class, needed_parts = nil) : {{type}}
      needed_bytes =
        if needed_parts
          needed_parts * sizeof(typeof(next_u))
        else
          sizeof({{type}})
        end

      buf = uninitialized UInt8[sizeof({{type}})]

      if needed_bytes < sizeof({{type}})
        bytes = Slice.new(buf.to_unsafe, needed_bytes)
        random_bytes(bytes)

        bytes.reduce({{type}}.new(0)) do |result, byte|
          (result << 8) | byte
        end
      else
        random_bytes(buf.to_slice)
        buf.unsafe_as({{type}})
      end
    end
  {% end %}

  {% for type in [Int8, Int16, Int32, Int64] %}
    private def self.rand_type(type : {{type}}.class, needed_bytes = sizeof({{type}})) : {{type}}
      result = rand_type({{"U#{type}".id}}, needed_bytes)
      {{type}}.new!(result)
    end
  {% end %}
end
