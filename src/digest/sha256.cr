require "./base"

# Implements the SHA256 digest algorithm.
class Digest::SHA256 < Digest::Base
  K = Array(UInt32){
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

  def initialize
    @state = uninitialized UInt32[8]
    @state[0] = 0x6a09e667_u32
    @state[1] = 0xbb67ae85_u32
    @state[2] = 0x3c6ef372_u32
    @state[3] = 0xa54ff53a_u32
    @state[4] = 0x510e527f_u32
    @state[5] = 0x9b05688c_u32
    @state[6] = 0x1f83d9ab_u32
    @state[7] = 0x5be0cd19_u32
    @blocks = 0
    @data = uninitialized UInt8[64]
    @datalen = 0
  end

  def update(data)
    data.to_slice.each do |byte|
      @data[@datalen] = byte.to_u8
      @datalen += 1
      if @datalen == 64
        process_message_block
        @blocks += 1
        @datalen = 0
      end
    end
  end

  def process_message_block
    m = uninitialized UInt32[64]

    16.times do |i|
      j = i * 4
      m[i] = (@data[j].to_u32 << 24) | (@data[j + 1].to_u32 << 16) | (@data[j + 2].to_u32 << 8) | (@data[j + 3].to_u32)
    end

    48.times do |i|
      i += 16
      m[i] = sig1(m[i - 2]) + m[i - 7] + sig0(m[i - 15]) + m[i - 16]
    end

    a = @state[0]
    b = @state[1]
    c = @state[2]
    d = @state[3]
    e = @state[4]
    f = @state[5]
    g = @state[6]
    h = @state[7]

    64.times do |i|
      t1 = h + ep1(e) + ch(e, f, g) + K.unsafe_at(i) + m[i]
      t2 = ep0(a) + maj(a, b, c)
      h = g
      g = f
      f = e
      e = d + t1
      d = c
      c = b
      b = a
      a = t1 + t2
    end

    @state[0] += a
    @state[1] += b
    @state[2] += c
    @state[3] += d
    @state[4] += e
    @state[5] += f
    @state[6] += g
    @state[7] += h
  end

  def rot_right(a, b)
    (a >> b) | (a << (32 - b))
  end

  def ch(x, y, z)
    (x & y) ^ (~x & z)
  end

  def maj(x, y, z)
    (x & y) ^ (x & z) ^ (y & z)
  end

  def ep0(x)
    rot_right(x, 2) ^ rot_right(x, 13) ^ rot_right(x, 22)
  end

  def ep1(x)
    rot_right(x, 6) ^ rot_right(x, 11) ^ rot_right(x, 25)
  end

  def sig0(x)
    rot_right(x, 7) ^ rot_right(x, 18) ^ (x >> 3)
  end

  def sig1(x)
    rot_right(x, 17) ^ rot_right(x, 19) ^ (x >> 10)
  end

  def final
    i = @datalen
    if @datalen < 56
      @data[i] = 0x80_u8
      i += 1
      while i < 56
        @data[i] = 0x00_u8
        i += 1
      end
    else
      @data[i] = 0x80_u8
      i += 1
      while i < 64
        @data[i] = 0x00_u8
        i += 1
      end
      process_message_block
      56.times do |i|
        @data[i] = 0_u8
      end
    end

    bitlen = @blocks.to_u64 * 512_u64 + @datalen.to_u64 * 8_u64
    @data[63] = (bitlen).to_u8
    @data[62] = (bitlen >> 8).to_u8
    @data[61] = (bitlen >> 16).to_u8
    @data[60] = (bitlen >> 24).to_u8
    @data[59] = (bitlen >> 32).to_u8
    @data[58] = (bitlen >> 40).to_u8
    @data[57] = (bitlen >> 48).to_u8
    @data[56] = (bitlen >> 56).to_u8
    process_message_block
  end

  def result
    hash = uninitialized UInt8[32]
    if IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian
      4.times do |i|
        hash[i] = (@state[0] >> (24 - i * 8)).to_u8
        hash[i + 4] = (@state[1] >> (24 - i * 8)).to_u8
        hash[i + 8] = (@state[2] >> (24 - i * 8)).to_u8
        hash[i + 12] = (@state[3] >> (24 - i * 8)).to_u8
        hash[i + 16] = (@state[4] >> (24 - i * 8)).to_u8
        hash[i + 20] = (@state[5] >> (24 - i * 8)).to_u8
        hash[i + 24] = (@state[6] >> (24 - i * 8)).to_u8
        hash[i + 28] = (@state[7] >> (24 - i * 8)).to_u8
      end
    else
      4.times do |i|
        hash[i] = (@state[0] >> (i * 8)).to_u8
        hash[i + 4] = (@state[1] >> (i * 8)).to_u8
        hash[i + 8] = (@state[2] >> (i * 8)).to_u8
        hash[i + 12] = (@state[3] >> (i * 8)).to_u8
        hash[i + 16] = (@state[4] >> (i * 8)).to_u8
        hash[i + 20] = (@state[5] >> (i * 8)).to_u8
        hash[i + 24] = (@state[6] >> (i * 8)).to_u8
        hash[i + 28] = (@state[7] >> (i * 8)).to_u8
      end
    end
    hash
  end
end
