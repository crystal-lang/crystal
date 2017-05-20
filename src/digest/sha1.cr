require "./base"

# Implements the SHA1 digest algorithm.
#
# Warning: SHA1 is no longer a cryptographically secure hash, and should not be
# used in security-related components, like password hashing. For passwords, see
# `Crypto::Bcrypt::Password`. For a generic cryptographic hash, use SHA-256 via
# `OpenSSL::Digest.new("SHA256")`.
class Digest::SHA1 < Digest::Base
  # This is a direct translation of https://tools.ietf.org/html/rfc3174#section-7
  # but we use loop unrolling for faster execution (about 1.07x slower than OpenSSL::SHA1).

  def initialize
    @intermediate_hash = uninitialized UInt32[5]
    @length_low = 0_u32
    @length_high = 0_u32
    @message_block = StaticArray(UInt8, 64).new(0_u8) # uninitialized UInt8[64]
    @message_block_index = 0

    @intermediate_hash[0] = 0x67452301_u32
    @intermediate_hash[1] = 0xEFCDAB89_u32
    @intermediate_hash[2] = 0x98BADCFE_u32
    @intermediate_hash[3] = 0x10325476_u32
    @intermediate_hash[4] = 0xC3D2E1F0_u32
  end

  def update(data)
    message_array = data.to_slice
    message_array.each do |byte|
      @message_block[@message_block_index] = byte & 0xFF_u8
      @message_block_index += 1
      @length_low += 8

      if @length_low == 0
        @length_high += 1
        if @length_high == 0
          raise ArgumentError.new "Crypto.sha1: message too long"
        end
      end

      if @message_block_index == 64
        process_message_block
      end
    end
  end

  def process_message_block
    k = {0x5A827999_u32, 0x6ED9EBA1_u32, 0x8F1BBCDC_u32, 0xCA62C1D6_u32}

    w = uninitialized UInt32[80]

    {% for t in (0...16) %}
      w[{{t}}] = @message_block[{{t}} * 4].to_u32 << 24
      w[{{t}}] |= @message_block[{{t}} * 4 + 1].to_u32 << 16
      w[{{t}}] |= @message_block[{{t}} * 4 + 2].to_u32 << 8
      w[{{t}}] |= @message_block[{{t}} * 4 + 3].to_u32
    {% end %}

    {% for t in (16...80) %}
      w[{{t}}] = circular_shift(1, w[{{t - 3}}] ^ w[{{t - 8}}] ^ w[{{t - 14}}] ^ w[{{t - 16}}])
    {% end %}

    a = @intermediate_hash[0]
    b = @intermediate_hash[1]
    c = @intermediate_hash[2]
    d = @intermediate_hash[3]
    e = @intermediate_hash[4]

    {% for t in (0...20) %}
      temp = circular_shift(5, a) +
        ((b & c) | ((~b) & d)) + e + w[{{t}}] + k[0]
      e = d
      d = c
      c = circular_shift(30, b)
      b = a
      a = temp
    {% end %}

    {% for t in (20...40) %}
      temp = circular_shift(5, a) + (b ^ c ^ d) + e + w[{{t}}] + k[1]
      e = d
      d = c
      c = circular_shift(30, b)
      b = a
      a = temp
    {% end %}

    {% for t in (40...60) %}
      temp = circular_shift(5, a) +
        ((b & c) | (b & d) | (c & d)) + e + w[{{t}}] + k[2]
      e = d
      d = c
      c = circular_shift(30, b)
      b = a
      a = temp
    {% end %}

    {% for t in (60...80) %}
      temp = circular_shift(5, a) + (b ^ c ^ d) + e + w[{{t}}] + k[3]
      e = d
      d = c
      c = circular_shift(30, b)
      b = a
      a = temp
    {% end %}

    @intermediate_hash[0] += a
    @intermediate_hash[1] += b
    @intermediate_hash[2] += c
    @intermediate_hash[3] += d
    @intermediate_hash[4] += e

    @message_block_index = 0
  end

  def circular_shift(bits, word)
    (word << bits) | (word >> (32 - bits))
  end

  def final
  end

  def result
    message_digest = uninitialized UInt8[20]
    pad_message

    @length_low = 0_u32
    @length_high = 0_u32
    {% for i in 0...20 %}
      message_digest[{{i}}] = (@intermediate_hash[{{i >> 2}}] >> 8 * (3 - ({{i & 0x03}}))).to_u8
    {% end %}

    message_digest
  end

  def pad_message
    if @message_block_index > 55
      @message_block[@message_block_index] = 0x80_u8
      @message_block_index += 1
      while @message_block_index < 64
        @message_block[@message_block_index] = 0_u8
        @message_block_index += 1
      end

      process_message_block

      while @message_block_index < 56
        @message_block[@message_block_index] = 0_u8
        @message_block_index += 1
      end
    else
      @message_block[@message_block_index] = 0x80_u8
      @message_block_index += 1
      while @message_block_index < 56
        @message_block[@message_block_index] = 0_u8
        @message_block_index += 1
      end
    end

    @message_block[56] = (@length_high >> 24).to_u8
    @message_block[57] = (@length_high >> 16).to_u8
    @message_block[58] = (@length_high >> 8).to_u8
    @message_block[59] = (@length_high).to_u8
    @message_block[60] = (@length_low >> 24).to_u8
    @message_block[61] = (@length_low >> 16).to_u8
    @message_block[62] = (@length_low >> 8).to_u8
    @message_block[63] = (@length_low).to_u8

    process_message_block
  end
end
