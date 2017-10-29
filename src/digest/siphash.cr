require "../digest"

# Copyright (c) 2012-2016 Jean-Philippe Aumasson <jeanphilippe.aumasson@gmail.com>
# Copyright (c) 2012-2014 Daniel J. Bernstein <djb@cr.yp.to>
#
# To the extent possible under law, the author(s) have dedicated all copyright
# and related and neighboring rights to this software to the public domain
# worldwide. This software is distributed without any warranty.
#
# You should have received a copy of the CC0 Public Domain Dedication along
# with this software. If not, see
# <http://creativecommons.org/publicdomain/zero/1.0/>.
#
# See also https://131002.net/siphash/

# SipHash is a family of pseudorandom functions optimized for short inputs.
#
# You may choose how many compression-rounds and finalization-rounds to execute.
# For example `SipHash(2, 4)` has been verified to be cryptographically secure,
# whereas `SipHash(1, 3)` is faster but not verified, and should only be used
# when the result is never disclosed (e.g. for table hashing).
#
# See <https://131002.net/siphash/> for more information.
#
# Example:
# ```
# key = uninitialized Digest::SipHash::Key
# Random::Secure.random_bytes(key.to_slice)
#
# hasher = Digest::SipHash(2, 4).new(key)
# hasher.update("some ")
# hasher.update("input data")
# hash = hasher.result
# ```
struct Digest::SipHash(CROUNDS, DROUNDS)
  alias Key = StaticArray(UInt8, 16)

  # :nodoc:
  BUF_SIZE = sizeof(UInt64)

  def initialize(key : Key)
    @buf = uninitialized UInt8[8] # UInt8[BUF_SIZE]
    @buf_index = 0
    @inlen = 0_u64

    k0 = u8to64_le(key.to_unsafe)
    k1 = u8to64_le(key.to_unsafe + 8)

    @v0 = 0x736f6d6570736575_u64
    @v1 = 0x646f72616e646f6d_u64
    @v2 = 0x6c7967656e657261_u64
    @v3 = 0x7465646279746573_u64

    @v3 ^= k1
    @v2 ^= k0
    @v1 ^= k1
    @v0 ^= k0
  end

  def update(data : String) : Nil
    update(data.to_unsafe, data.bytesize)
  end

  def update(data : Bytes) : Nil
    update(data.to_unsafe, data.size)
  end

  protected def update(data : UInt8*, datalen : Int32) : Nil
    @inlen += datalen
    done = data + datalen
    v0, v1, v2, v3 = @v0, @v1, @v2, @v3

    unless @buf_index == 0
      # fill incomplete 8-byte buffer
      count = Math.min(datalen, BUF_SIZE - @buf_index)
      data.copy_to(@buf.to_unsafe + @buf_index, count)

      size = @buf_index + count
      unless size == BUF_SIZE
        @buf_index = size
        return
      end

      # compress 8-byte buffer
      update(@buf.to_unsafe)

      @buf_index = 0
      data += count
      datalen -= count
    end

    # compress has many 8-bytes as possible
    stop = data + (datalen - datalen % BUF_SIZE)
    until data == stop
      update(data)
      data += BUF_SIZE
    end

    # save incomplete 8-byte to buffer
    unless stop == done
      @buf_index = left = datalen & 7
      data.copy_to(@buf.to_unsafe, left)
    end

    @v0, @v1, @v2, @v3 = v0, v1, v2, v3
  end

  private macro update(input)
    m = u8to64_le({{input}})
    v3 ^= m

    CROUNDS.times { sipround }

    v0 ^= m
  end

  def result
    output = uninitialized UInt64
    result(@buf.to_unsafe, @buf_index, pointerof(output).as(UInt8*))
    output
  end

  def result(output : Bytes) : Nil
    raise ArgumentError.new("Digest::SipHash can only generate 8 bytes hashes.") unless output.size == 8
    result(@buf.to_unsafe, @buf_index, output.to_unsafe)
  end

  protected def result(input : UInt8*, left : Int32, output : UInt8*) : Nil
    b = @inlen << 56
    v0, v1, v2, v3 = @v0, @v1, @v2, @v3

    case left
    when 7
      b |= input[6].to_u64 << 48
      b |= input[5].to_u64 << 40
      b |= input[4].to_u64 << 32
      b |= input[3].to_u64 << 24
      b |= input[2].to_u64 << 16
      b |= input[1].to_u64 << 8
      b |= input[0].to_u64
    when 6
      b |= input[5].to_u64 << 40
      b |= input[4].to_u64 << 32
      b |= input[3].to_u64 << 24
      b |= input[2].to_u64 << 16
      b |= input[1].to_u64 << 8
      b |= input[0].to_u64
    when 5
      b |= input[4].to_u64 << 32
      b |= input[3].to_u64 << 24
      b |= input[2].to_u64 << 16
      b |= input[1].to_u64 << 8
      b |= input[0].to_u64
    when 4
      b |= input[3].to_u64 << 24
      b |= input[2].to_u64 << 16
      b |= input[1].to_u64 << 8
      b |= input[0].to_u64
    when 3
      b |= input[2].to_u64 << 16
      b |= input[1].to_u64 << 8
      b |= input[0].to_u64
    when 2
      b |= input[1].to_u64 << 8
      b |= input[0].to_u64
    when 1
      b |= input[0].to_u64
    end

    v3 ^= b

    CROUNDS.times { sipround }

    v0 ^= b
    v2 ^= 0xff

    DROUNDS.times { sipround }

    b = v0 ^ v1 ^ v2 ^ v3
    u64to8_le(output, b)
  end

  private def rotl(x, b) : UInt64
    (x << b) | x >> (64 - b)
  end

  private def u32to8_le(p, v)
    p[0] = v.to_u8
    p[1] = (v >> 8).to_u8
    p[2] = (v >> 16).to_u8
    p[3] = (v >> 24).to_u8
  end

  private def u64to8_le(p, v)
    u32to8_le(p, v.to_u32)
    u32to8_le(p + 4, (v >> 32).to_u32)
  end

  private def u8to64_le(p)
    p[0].to_u64 | (p[1].to_u64 << 8) |
      (p[2].to_u64 << 16) | (p[3].to_u64 << 24) |
      (p[4].to_u64 << 32) | (p[5].to_u64 << 40) |
      (p[6].to_u64 << 48) | (p[7].to_u64 << 56)
  end

  private macro sipround
    v0 += v1
    v1 = rotl(v1, 13)
    v1 ^= v0
    v0 = rotl(v0, 32)
    v2 += v3
    v3 = rotl(v3, 16)
    v3 ^= v2
    v0 += v3
    v3 = rotl(v3, 21)
    v3 ^= v0
    v2 += v1
    v1 = rotl(v1, 17)
    v1 ^= v2
    v2 = rotl(v2, 32)
  end
end
