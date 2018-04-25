require "crystal/system/random"

# Generates random numbers from a secure source provided by the system.
#
# For example `arc4random` is used on OpenBSD, whereas on Linux it uses
# `getrandom` (if the kernel supports it) and fallbacks on reading from
# `/dev/urandom` on UNIX systems.
#
# ```
# Random::Secure.rand(6)            # => 4
# [1, 5, 6].shuffle(Random::Secure) # => [6, 1, 5]
# ```
module Random::Secure
  extend Random
  extend self

  def next_u
    Crystal::System::Random.next_u
  end

  def random_bytes(buf : Bytes)
    Crystal::System::Random.random_bytes(buf)
  end

  {% for type in [UInt8, UInt16, UInt32, UInt64] %}
    # Generates a random integer of a given type. The number of bytes to
    # generate can be limited; by default it will generate as many bytes as
    # needed to fill the integer size.
    private def rand_type(type : {{type}}.class, needed_parts = nil) : {{type}}
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
    private def rand_type(type : {{type}}.class, needed_bytes = sizeof({{type}})) : {{type}}
      result = rand_type({{"U#{type}".id}}, needed_bytes)
      {{type}}.new(result)
    end
  {% end %}
end
