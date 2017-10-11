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

# An alternative to `Digest::SipHash` pseudorandom function that uses a 64-bit
# key and generates 32-bit or 64-bit hashes, meant for 32-bit platforms. On
# 64-bit platform we advise to use `SipHash` instead.
#
# While `SipHash(2, 4)` has been analyzed and verified to be cryptographically
# secure, `HalfSipHash` has not, and isn't expected to be. Results from the
# hasher should never be disclosed (e.g. use for table hashing on 32-bit).
#
# See <https://131002.net/siphash/> for more information.
#
# Example:
# ```
# key = uninitialized Digest::HalfSipHash::Key
# Random::Secure.random_bytes(key.to_slice)
#
# hasher = Digest::HalfSipHash(2, 4).new(key)
# hasher.update("some ")
# hasher.update("input data")
# hash = hasher.result
# ```
struct Digest::HalfSipHash(CROUNDS, DROUNDS)
  alias Key = StaticArray(UInt8, 8)

  # :nodoc:
  BUF_SIZE = sizeof(UInt32)

  def initialize(key : Key)
    @buf = uninitialized UInt8[4] # UInt8[BUF_SIZE]
    @buf_index = 0
    @inlen = 0_u32

    k0 = u8to32_le(key.to_unsafe)
    k1 = u8to32_le(key.to_unsafe + 4)

    @v0 = 0_u32
    @v1 = 0_u32
    @v2 = 0x6c796765_u32
    @v3 = 0x74656462_u32

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
      # fill incomplete 4-byte buffer
      count = Math.min(datalen, BUF_SIZE - @buf_index)
      data.copy_to(@buf.to_unsafe + @buf_index, count)

      size = @buf_index + count
      unless size == BUF_SIZE
        @buf_index = size
        return
      end

      # compress 4-byte buffer
      update(@buf.to_unsafe)

      @buf_index = 0
      data += count
      datalen -= count
    end

    # compress has many 4-bytes as possible
    stop = data + (datalen - datalen % BUF_SIZE)
    until data == stop
      update(data)
      data += BUF_SIZE
    end

    # save incomplete 4-byte to buffer
    unless stop == done
      @buf_index = left = datalen & 3
      data.copy_to(@buf.to_unsafe, left)
    end

    @v0, @v1, @v2, @v3 = v0, v1, v2, v3
  end

  private macro update(input)
    m = u8to32_le({{input}})
    v3 ^= m

    CROUNDS.times { sipround }

    v0 ^= m
  end

  def result
    output = uninitialized UInt32
    result(@buf.to_unsafe, @buf_index, pointerof(output).as(UInt8*))
    output
  end

  def result(output : Bytes) : Nil
    raise ArgumentError.new("Digest::HalfSipHash can only generate 4 bytes hashes.") unless output.size == 4
    result(@buf.to_unsafe, @buf_index, output.to_unsafe)
  end

  protected def result(input : UInt8*, left : Int32, output : UInt8*) : Nil
    b = @inlen << 24
    v0, v1, v2, v3 = @v0, @v1, @v2, @v3

    case left
    when 3
      b |= input[2].to_u32 << 16
      b |= input[1].to_u32 << 8
      b |= input[0].to_u32
    when 2
      b |= input[1].to_u32 << 8
      b |= input[0].to_u32
    when 1
      b |= input[0].to_u32
    end

    v3 ^= b

    CROUNDS.times { sipround }

    v0 ^= b
    v2 ^= 0xff

    DROUNDS.times { sipround }

    b = v1 ^ v3
    u32to8_le(output, b)
  end

  private def rotl(x, b)
    (x << b) | x >> (32 - b)
  end

  private def u32to8_le(p, v)
    p[0] = v.to_u8
    p[1] = (v >> 8).to_u8
    p[2] = (v >> 16).to_u8
    p[3] = (v >> 24).to_u8
  end

  private def u8to32_le(p)
    p[0].to_u32 |
      (p[1].to_u32 << 8) |
      (p[2].to_u32 << 16) |
      (p[3].to_u32 << 24)
  end

  private macro sipround
    v0 += v1
    v1 = rotl(v1, 5)
    v1 ^= v0
    v0 = rotl(v0, 16)
    v2 += v3
    v3 = rotl(v3, 8)
    v3 ^= v2
    v0 += v3
    v3 = rotl(v3, 7)
    v3 ^= v0
    v2 += v1
    v1 = rotl(v1, 13)
    v1 ^= v2
    v2 = rotl(v2, 16)
  end
end
