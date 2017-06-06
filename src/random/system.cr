require "crystal/system/random"

# Generates random numbers from a secure source of the system.
#
# For example `arc4random` is used on OpenBSD, whereas on Linux it uses
# `getrandom` (if the kernel supports it) and fallbacks on reading from
# `/dev/urandom` on UNIX systems.
struct Random::System
  include Random

  def initialize
  end

  def next_u
    Crystal::System::Random.next_u
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
        Crystal::System::Random.random_bytes(bytes)

        bytes.reduce({{type}}.new(0)) do |result, byte|
          (result << 8) | byte
        end
      else
        Crystal::System::Random.random_bytes(buf.to_slice)
        buf.to_unsafe.as({{type}}*).value
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
