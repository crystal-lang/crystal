require "base64"

module Digest::SHA256
  def self.digest(string : String)
    digest(string.to_slice)
  end

  def self.digest(slice : Slice(UInt8))
    context = Context.new
    context.input(slice)
    context.result
  end

  def self.hexdigest(string_or_slice : String | Slice(UInt8)) : String
    digest(string_or_slice).to_slice.hexstring
  end

  def self.base64digest(string_or_slice : String | Slice(UInt8)) : String
    Base64.strict_encode(digest(string_or_slice).to_slice)
  end

  # :nodoc:
  struct Context
    # An implementation of SHA256 based on the existing SHA1 crystal implementation.

    def initialize
      @intermediate_hash = uninitialized UInt32[8]
      @length_low = 0_u32
      @length_high = 0_u32
      @message_block = StaticArray(UInt8, 64).new(0_u8) # uninitialized UInt8[64]
      @message_block_index = 0

      @intermediate_hash[0] = 0x6A09E667_u32
      @intermediate_hash[1] = 0xBB67AE85_u32
      @intermediate_hash[2] = 0x3C6EF372_u32
      @intermediate_hash[3] = 0xA54FF53A_u32
      @intermediate_hash[4] = 0x510E527F_u32
      @intermediate_hash[5] = 0x9B05688C_u32
      @intermediate_hash[6] = 0x1F83D9AB_u32
      @intermediate_hash[7] = 0x5BE0CD19_u32
    end

    def input(message_array : Slice(UInt8))
      message_array.each do |byte|
        @message_block[@message_block_index] = byte & 0xFF_u8
        @message_block_index += 1
        @length_low += 8

        if @length_low == 0
          @length_high += 1
          if @length_high == 0
            raise ArgumentError.new "Crypto.sha256: message too long"
          end
        end

        if @message_block_index == 64
          process_message_block
        end
      end
    end

    def process_message_block
      k = {
        0x428a2f98_u32, 0x71374491_u32, 0xb5c0fbcf_u32, 0xe9b5dba5_u32,
        0x3956c25b_u32, 0x59f111f1_u32, 0x923f82a4_u32, 0xab1c5ed5_u32,
        0xd807aa98_u32, 0x12835b01_u32, 0x243185be_u32, 0x550c7dc3_u32,
        0x72be5d74_u32, 0x80deb1fe_u32, 0x9bdc06a7_u32, 0xc19bf174_u32,
        0xe49b69c1_u32, 0xefbe4786_u32, 0x0fc19dc6_u32, 0x240ca1cc_u32,
        0x2de92c6f_u32, 0x4a7484aa_u32, 0x5cb0a9dc_u32, 0x76f988da_u32,
        0x983e5152_u32, 0xa831c66d_u32, 0xb00327c8_u32, 0xbf597fc7_u32,
        0xc6e00bf3_u32, 0xd5a79147_u32, 0x06ca6351_u32, 0x14292967_u32,
        0x27b70a85_u32, 0x2e1b2138_u32, 0x4d2c6dfc_u32, 0x53380d13_u32,
        0x650a7354_u32, 0x766a0abb_u32, 0x81c2c92e_u32, 0x92722c85_u32,
        0xa2bfe8a1_u32, 0xa81a664b_u32, 0xc24b8b70_u32, 0xc76c51a3_u32,
        0xd192e819_u32, 0xd6990624_u32, 0xf40e3585_u32, 0x106aa070_u32,
        0x19a4c116_u32, 0x1e376c08_u32, 0x2748774c_u32, 0x34b0bcb5_u32,
        0x391c0cb3_u32, 0x4ed8aa4a_u32, 0x5b9cca4f_u32, 0x682e6ff3_u32,
        0x748f82ee_u32, 0x78a5636f_u32, 0x84c87814_u32, 0x8cc70208_u32,
        0x90befffa_u32, 0xa4506ceb_u32, 0xbef9a3f7_u32, 0xc67178f2_u32,
      }

      w = uninitialized UInt32[64]

      {% for t in (0...16) %}
        w[{{t}}] = @message_block[{{t}} * 4].to_u32 << 24
        w[{{t}}] |= @message_block[{{t}} * 4 + 1].to_u32 << 16
        w[{{t}}] |= @message_block[{{t}} * 4 + 2].to_u32 << 8
        w[{{t}}] |= @message_block[{{t}} * 4 + 3].to_u32
      {% end %}

      {% for t in (16...64) %}
        s0 = right_rotate(7, w[{{t - 15}}]) ^ right_rotate(18, w[{{t - 15}}]) ^ (w[{{t - 15}}] >> 3)
        s1 = right_rotate(17, w[{{t - 2}}]) ^ right_rotate(19, w[{{t - 2}}]) ^ (w[{{t - 2}}] >> 10)
        w[{{t}}] = w[{{t - 16}}] + s0 + w[{{t - 7}}] + s1
      {% end %}

      a = @intermediate_hash[0]
      b = @intermediate_hash[1]
      c = @intermediate_hash[2]
      d = @intermediate_hash[3]
      e = @intermediate_hash[4]
      f = @intermediate_hash[5]
      g = @intermediate_hash[6]
      h = @intermediate_hash[7]

      {% for t in (0...64) %}
        s1 = right_rotate(6, e) ^ right_rotate(11, e) ^ right_rotate(25, e)
        ch = (e & f) ^ ((~e) & g)
        temp1 = h + s1 + ch + k[{{t}}] + w[{{t}}]
        s0 = right_rotate(2, a) ^ right_rotate(13, a) ^ right_rotate(22, a)
        maj = (a & b) ^ (a & c) ^ (b & c)
        temp2 = s0 + maj

        h = g
        g = f
        f = e
        e = d + temp1
        d = c
        c = b
        b = a
        a = temp1 + temp2
      {% end %}

      @intermediate_hash[0] += a
      @intermediate_hash[1] += b
      @intermediate_hash[2] += c
      @intermediate_hash[3] += d
      @intermediate_hash[4] += e
      @intermediate_hash[5] += f
      @intermediate_hash[6] += g
      @intermediate_hash[7] += h

      @message_block_index = 0
    end

    def right_rotate(bits, word)
      (word >> bits) | (word << (32 - bits))
    end

    def result
      message_digest = uninitialized UInt8[32]
      pad_message

      @length_low = 0_u32
      @length_high = 0_u32

      {% for i in 0...32 %}
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
end
