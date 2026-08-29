require "crystal/system/random"

# `Random::Secure` generates random numbers from a secure source provided by the system.
#
# It uses a [cryptographically secure pseudorandom number generator (CSPRNG)](https://en.wikipedia.org/wiki/Cryptographically_secure_pseudorandom_number_generator)
# for cryptography and secure usages such as generating secret keys, or to seed
# another pseudorandom number generator (PRNG).
#
# ```
# Random::Secure.rand(6)            # => 4
# [1, 5, 6].shuffle(Random::Secure) # => [6, 1, 5]
# ```
#
# On BSD-based systems and macOS/Darwin, it uses [`arc4random`](https://man.openbsd.org/arc4random),
# on Linux [`getrandom`](http://man7.org/linux/man-pages/man2/getrandom.2.html),
# on Windows [`RtlGenRandom`](https://docs.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-rtlgenrandom),
# and falls back to reading from `/dev/urandom` on UNIX systems.
module Random::Secure
  extend Random
  extend self

  def next_u
    Crystal::System::Random.next_u
  end

  def random_bytes(buf : Bytes) : Nil
    Crystal::System::Random.random_bytes(buf)
  end

  {% for type in [UInt8, UInt16, UInt32, UInt64, UInt128] %}
    # Generates a random integer of a given type. The number of bytes to
    # generate can be limited; by default it will generate as many bytes as
    # needed to fill the integer size.
    private def rand_type(type : {{ type }}.class, needed_parts = nil) : {{ type }}
      needed_bytes =
        if needed_parts
          needed_parts * sizeof(typeof(next_u))
        else
          sizeof({{ type }})
        end

      buf = uninitialized UInt8[sizeof({{ type }})]

      if needed_bytes < sizeof({{ type }})
        bytes = Slice.new(buf.to_unsafe, needed_bytes)
        random_bytes(bytes)

        bytes.reduce({{ type }}.new(0)) do |result, byte|
          (result << 8) | byte
        end
      else
        random_bytes(buf.to_slice)
        buf.unsafe_as({{ type }})
      end
    end
  {% end %}

  {% for type in [Int8, Int16, Int32, Int64, Int128] %}
    private def rand_type(type : {{ type }}.class, needed_bytes = sizeof({{ type }})) : {{ type }}
      result = rand_type({{ "U#{type}".id }}, needed_bytes)
      {{ type }}.new!(result)
    end
  {% end %}
end
