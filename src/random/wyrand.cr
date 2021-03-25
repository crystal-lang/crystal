require "random/secure"

# A native Crystal implementation of the beautifully simple and impressively
# fast PRNG from Wyhash.
#
# Based on the original C implementation by 王一 (Wang Yi).
# https://github.com/wangyi-fudan/wyhash
#
# Provides a 64 bit output based on mix and multply operation. This provides
# exceptionly fast performance on modern processors, but may yield slower
# results on older architectures.
struct Random::Wyrand
  include Random

  private P = {0xa0761d6478bd642f_u64, 0xe7037ed1a0b428db_u64}

  @state : UInt64

  def initialize(seed = Random::Secure.rand(UInt64))
    @state = seed
  end

  def next_u : UInt64
    a = @state &+= P[0]
    b = a ^ P[1]

    r = UInt128.new! a
    r &*= b

    p = pointerof(r).as UInt64*
    a = p.value
    b = (p + 1).value

    a ^ b
  end

  {% for size in [8, 16, 32, 64] %}
    {% type = "UInt#{size}".id %}

    def rand(type : {{type}}.class) : {{type}}
      r = next_u
      p = pointerof(r).as {{type}}*
      p.value
    end

    private def rand_int(max : {{type}}) : {{type}}
      a = next_u
      b = UInt64.new! max

      r = UInt128.new! a
      r &*= b

      p = pointerof(r).as {{type}}*
      (p + {{128 // size - 1}}).value
    end
  {% end %}
end

# TODO: BidEndian support. Crystal is currently pinned to LittleEndian so low
# priority. This is here as a guard rail for when this changes.
{% if IO::ByteFormat::SystemEndian != IO::ByteFormat::LittleEndian %}
  {{ raise "Wyrand BigEndian support not implemented" }}
{% end %}
