# Generates random numbers from a secure source of the system.
#
# For example `arc4random` is used on OpenBSD, whereas on Linux it uses
# `getrandom` (if the kernel supports it) and fallbacks on reading from
# `/dev/urandom` on UNIX systems.
#
# ```
# Random::System.rand(6)            # => 4
# [1, 5, 6].shuffle(Random::System) # => [6, 1, 5]
# ```
module Random::System
  extend Random
  extend self

  # Fills *buffer* with random bytes from a secure source.
  def random_bytes(buffer : Bytes) : Nil
    {% raise "Not implemented for this system" %}
  end

  # Returns a random unsigned integer from a secure source. Implementations
  # may choose the integer size to return based on what the system source
  # provides. They may choose to return a single byte (UInt8) in which case
  # `::Random` will prefer `#random_bytes` to read as many bytes as required
  # at once, avoiding multiple reads or reading too many bytes.
  def next_u
    {% raise "Not implemented for this system" %}
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

require "platform_specific/random"
