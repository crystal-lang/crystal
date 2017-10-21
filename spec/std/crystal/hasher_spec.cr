require "spec"
require "bit_array"
require "random/secure"

struct Crystal::Hasher
  struct SpecResult
    def initialize(@v = 0_u64)
    end

    def differs(other)
      @v.should_not eq(other.@v)
      (@v ^ other.@v).popcount.should be_close(32, 24)
    end
  end

  def self.bytes(b)
    SpecResult.new(new.bytes(b).result)
  end
end

# Note: this tests are probabilistic.
# Hasher is randomly seeded, therefore this tests could randomly
# fail. Probability of fail is very very low, but not zero.
# If test fails two times in a row, then error is certainly real.
describe "Hasher" do
  describe "bytes" do
    it "should differ for every single bit and length" do
      empty_hash = Crystal::Hasher.bytes(Bytes.new(0))
      1.upto(64) do |byte_len|
        bytes = Bytes.new(byte_len, 0_u8)
        zero_hash = Crystal::Hasher.bytes(bytes)
        prev_hash = zero_hash
        prev_prev_hash = Crystal::Hasher::SpecResult.new
        bit_len = byte_len * 8
        0.upto(bit_len - 1) do |bit|
          bytes[bit/8] ^= 1 << (bit & 7)
          cur_hash = Crystal::Hasher.bytes(bytes)
          cur_hash.differs empty_hash
          cur_hash.differs zero_hash
          cur_hash.differs prev_hash
          cur_hash.differs prev_prev_hash
          prev_hash, prev_prev_hash = cur_hash, prev_hash
          # check for other random bit
          while true
            other_bit = rand(bit_len)
            break if other_bit != bit
          end
          bytes[other_bit/8] ^= 1 << (other_bit & 7)
          oth_hash = Crystal::Hasher.bytes(bytes)
          cur_hash.differs oth_hash
          bytes[other_bit/8] ^= 1 << (other_bit & 7)
          # check for length extention
          (byte_len - 1).downto((bit + 7)/8) do |len|
            short_hash = Crystal::Hasher.bytes(bytes[0, len])
            cur_hash.differs short_hash
          end
          bytes[bit/8] ^= 1 << (bit & 7)
        end
      end
    end

    it "should change for every single bit flip" do
      empty_hash = Crystal::Hasher.bytes(Bytes.new(0))
      1.upto(64) do |byte_len|
        bytes = Bytes.new(byte_len, 0_u8)
        Random::Secure.random_bytes(bytes)
        zero_hash = Crystal::Hasher.bytes(bytes)
        prev_hash = zero_hash
        prev_prev_hash = Crystal::Hasher::SpecResult.new
        bit_len = byte_len * 8
        0.upto(bit_len - 1) do |bit|
          bytes[bit/8] ^= 1 << (bit & 7)
          cur_hash = Crystal::Hasher.bytes(bytes)
          cur_hash.differs empty_hash
          cur_hash.differs zero_hash
          cur_hash.differs prev_hash
          cur_hash.differs prev_prev_hash
          prev_hash, prev_prev_hash = cur_hash, prev_hash
          # check for other random bit
          while true
            other_bit = rand(bit_len)
            break if other_bit != bit
          end
          bytes[other_bit/8] ^= 1 << (other_bit & 7)
          oth_hash = Crystal::Hasher.bytes(bytes)
          cur_hash.differs oth_hash
          bytes[other_bit/8] ^= 1 << (other_bit & 7)
          bytes[bit/8] ^= 1 << (bit & 7)
        end
      end
    end
  end

  describe "int" do
    it "should satisfy birthday paradox (32)" do
      d = 2**22
      d1d = (d.to_f - 1.0)/d.to_f
      bits = Array.new(4) { BitArray.new(d) }
      counts = [0, 0, 0]
      65537.times do |i|
        hsh = (i * 0xcafebeef).hash
        vals = [hsh, hsh >> 22, hsh >> 42]
        3.times do |j|
          pos = vals[j] & (d - 1)
          if bits[j][pos]
            counts[j] += 1
          else
            bits[j][pos] = true
          end
        end
        if i > 30000 && i % 1024 == 0
          expected = (i - d).to_f + d * d1d**i
          3.times do |j|
            counts[j].should be_close(expected, expected/2)
          end
        end
      end
    end

    it "should satisfy birthday paradox (64)" do
      d = 2**22
      d1d = (d.to_f - 1.0)/d.to_f
      bits = Array.new(4) { BitArray.new(d) }
      counts = [0, 0, 0]
      v = 0_u64
      165537.times do |i|
        v = v*5 + 1
        hsh = v.hash
        vals = [hsh, hsh >> 22, hsh >> 42]
        3.times do |j|
          pos = vals[j] & (d - 1)
          if bits[j][pos]
            counts[j] += 1
          else
            bits[j][pos] = true
          end
        end
        if i > 30000 && i % 1024 == 0
          expected = (i - d).to_f + d * d1d**i
          3.times do |j|
            counts[j].should be_close(expected, expected/2)
          end
        end
      end
    end
  end
end
