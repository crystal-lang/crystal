require "spec"
require "bit_array"
require "../spec_helper"
require "big"
require "random/secure"

struct Crystal::Hasher
  def self.for_test
    new(1_u64, 1_u64)
  end
end

enum TestHasherEnum
  A
  B
end

alias TestHasher = Crystal::Hasher

describe "Crystal::Hasher" do
  context "behavior" do
    it "#nil should change hasher state" do
      hasher = TestHasher.for_test
      hasher1 = nil.hash(hasher)
      hasher2 = nil.hash(hasher1)
      hasher1.result.should_not eq(hasher.result)
      hasher2.result.should_not eq(hasher.result)
      hasher2.result.should_not eq(hasher1.result)
    end

    it "#bool should change state and differ" do
      hasher = TestHasher.for_test
      hasher_true = true.hash(hasher)
      hasher_false = false.hash(hasher)
      hasher.result.should_not eq(hasher_true.result)
      hasher.result.should_not eq(hasher_false.result)
      hasher_true.result.should_not eq(hasher_false.result)
    end

    it "#int should change state and differ" do
      hasher = TestHasher.for_test
      hasher1 = 1.hash(hasher)
      hasher2 = 2.hash(hasher)
      hasher12 = 2.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each { |(a, b)| a.should_not eq(b) }
    end

    it "#int should be equal for different types" do
      1.hash.should eq(1_u64.hash)
      2.hash.should eq(2_u64.hash)
    end

    it "Big i64 numbers should be hashed ok" do
      Int64::MAX.hash.should eq(Int64::MAX.hash)
    end

    {% if flag?(:bits64) %}
      it "128bit types should be hashed ok" do
        1.to_i128.hash.should eq(1_i8.hash)
        1.to_u128.hash.should eq(1_u8.hash)
      end
    {% end %}

    it "#float should change state and differ" do
      hasher = TestHasher.for_test
      hasher1 = 1.0.hash(hasher)
      hasher2 = 2.0.hash(hasher)
      hasher12 = 2.0.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each { |(a, b)| a.should_not eq(b) }
    end

    it "#char should change state and differ" do
      hasher = TestHasher.for_test
      hasher1 = 'a'.hash(hasher)
      hasher2 = 'b'.hash(hasher)
      hasher12 = 'b'.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each { |(a, b)| a.should_not eq(b) }
    end

    it "#enum should change state and differ" do
      hasher = TestHasher.for_test
      hasher1 = TestHasherEnum::A.hash(hasher)
      hasher2 = TestHasherEnum::B.hash(hasher)
      hasher12 = TestHasherEnum::B.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each { |(a, b)| a.should_not eq(b) }
    end

    it "#symbol should change state and differ" do
      hasher = TestHasher.for_test
      hasher1 = :A.hash(hasher)
      hasher2 = :B.hash(hasher)
      hasher12 = :B.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each { |(a, b)| a.should_not eq(b) }
    end

    it "#reference should change state and differ" do
      hasher = TestHasher.for_test
      a, b = Reference.new, Reference.new
      hasher1 = a.hash(hasher)
      hasher2 = b.hash(hasher)
      hasher12 = b.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each { |(a, b)| a.should_not eq(b) }
    end

    it "#string should change state and differ" do
      hasher = TestHasher.for_test
      hasher1 = "a".hash(hasher)
      hasher2 = "b".hash(hasher)
      hasher12 = "b".hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each { |(a, b)| a.should_not eq(b) }
    end

    it "#class should change state and differ" do
      hasher = TestHasher.for_test
      hasher1 = TestHasher.hash(hasher)
      hasher2 = TestHasherEnum.hash(hasher)
      hasher12 = TestHasherEnum.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each { |(a, b)| a.should_not eq(b) }
    end

    it "#bytes should change state and differ" do
      hasher = TestHasher.for_test
      a = Bytes[1, 2, 3]
      b = Bytes[2, 3, 4]
      hasher1 = a.hash(hasher)
      hasher2 = b.hash(hasher)
      hasher12 = b.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each { |(a, b)| a.should_not eq(b) }
    end
  end

  context "funny_hash" do
    it "result should work" do
      hasher = TestHasher.new(1_u64, 1_u64)
      typeof(hasher.result).should eq(UInt64)
      hasher.result.should eq(0x162c591a100060e5_u64)

      hasher = TestHasher.new(1_u64, 2_u64)
      hasher.result.should eq(0x7f8304f0947082d1_u64)

      hasher = TestHasher.new(2_u64, 1_u64)
      hasher.result.should eq(0xc302065c9b909fdf_u64)

      hasher = TestHasher.new(0x123456789abcdef0_u64, 0x016fcd2b89e745a3_u64)
      hasher.result.should eq(0x54258afe17b6a4bb_u64)

      # "bad seed"
      hasher = TestHasher.new(0_u64, 0_u64)
      hasher.result.should eq(0_u64)
    end

    it "#nil should match test vectors" do
      hasher = TestHasher.for_test
      hasher1 = nil.hash(hasher)
      hasher2 = nil.hash(hasher1)
      hasher1.result.should eq(0x2c58b2332000c1cb_u64)
      hasher2.result.should eq(0xef5ab89129b8991b_u64)
    end

    it "#bool should match test vectors" do
      hasher = TestHasher.for_test
      hasher_true = true.hash(hasher)
      hasher_false = false.hash(hasher)
      hasher_true.result.should eq(0x94e4534c12903881_u64)
      hasher_false.result.should eq(0x15cf71e56618745b_u64)
    end

    it "#int should match test vectors" do
      hasher = TestHasher.for_test
      hasher1 = 1.hash(hasher)
      hasher2 = 2.hash(hasher)
      hasher1.result.should eq(0x94e4534c12903881_u64)
      hasher2.result.should eq(0xaf42909720d981e7_u64)
    end

    it "#float should match test vectors" do
      hasher = TestHasher.for_test
      hasher1 = 1.0.hash(hasher)
      hasher2 = 2.0.hash(hasher)
      hasher1.result.should eq(10728791798497425537_u64)
      hasher2.result.should eq(12628815283865879015_u64)
    end

    it "#string should match test vectors" do
      hasher = TestHasher.for_test
      hasher0 = "".hash(hasher)
      hasher1 = "1".hash(hasher)
      hasher2 = "2.0".hash(hasher)
      hasher0.result.should eq(0x15cf71e56618745b_u64)
      hasher1.result.should eq(0x70ef623beff8c213_u64)
      hasher2.result.should eq(0x2908fdd2bb81fbed_u64)
    end
  end

  describe "to_s" do
    it "should not expose internal data" do
      hasher = TestHasher.new(1_u64, 2_u64)
      hasher.to_s.should_not contain('1')
      hasher.to_s.should_not contain(hasher.@a.to_s)
      hasher.to_s.should_not contain(hasher.@a.to_s(16))
      hasher.to_s.should_not contain('2')
      hasher.to_s.should_not contain(hasher.@b.to_s)
      hasher.to_s.should_not contain(hasher.@b.to_s(16))
    end
  end

  describe "inspect" do
    it "should not expose internal data" do
      hasher = TestHasher.new(1_u64, 2_u64)
      hasher.inspect.should_not contain('1')
      hasher.inspect.should_not contain(hasher.@a.to_s)
      hasher.inspect.should_not contain(hasher.@a.to_s(16))
      hasher.inspect.should_not contain('2')
      hasher.inspect.should_not contain(hasher.@b.to_s)
      hasher.inspect.should_not contain(hasher.@b.to_s(16))
    end
  end

  describe "normalization of numbers" do
    it "should 1_i32 and 1_f64 hashes equal" do
      1_i32.hash.should eq(1_f64.hash)
    end

    it "should 1_f32 and 1.to_big_f hashes equal" do
      1_f32.hash.should eq(1.to_big_f.hash)
    end

    it "should 1_f32 and 1.to_big_r hashes equal" do
      1_f32.hash.should eq(1.to_big_r.hash)
    end

    it "should 1_f32 and 1.to_big_i hashes equal" do
      1_f32.hash.should eq(1.to_big_i.hash)
    end
  end

  describe ".reduce_num" do
    it "reduces primitive int" do
      {% for int in Int::Primitive.union_types %}
        Crystal::Hasher.reduce_num({{ int }}.new(0)).should eq(0_u64)
        Crystal::Hasher.reduce_num({{ int }}.new(1)).should eq(1_u64)
        Crystal::Hasher.reduce_num({{ int }}::MAX).should eq(UInt64.new!({{ int }}::MAX % 0x1FFF_FFFF_FFFF_FFFF_u64))
      {% end %}

      {% for int in Int::Signed.union_types %}
        Crystal::Hasher.reduce_num({{ int }}.new(-1)).should eq(UInt64::MAX)
        Crystal::Hasher.reduce_num({{ int }}::MIN).should eq(UInt64::MAX - UInt64.new!({{ int }}::MAX % 0x1FFF_FFFF_FFFF_FFFF_u64))
      {% end %}
    end

    it "reduces primitive float" do
      {% for float in Float::Primitive.union_types %}
        Crystal::Hasher.reduce_num({{ float }}.new(0)).should eq(0_u64)
        Crystal::Hasher.reduce_num({{ float }}.new(1)).should eq(1_u64)
        Crystal::Hasher.reduce_num({{ float }}.new(-1)).should eq(UInt64::MAX)
        Crystal::Hasher.reduce_num({{ float }}::INFINITY).should eq(Crystal::Hasher::HASH_INF_PLUS)
        Crystal::Hasher.reduce_num(-{{ float }}::INFINITY).should eq(Crystal::Hasher::HASH_INF_MINUS)
        Crystal::Hasher.reduce_num({{ float }}::NAN).should eq(Crystal::Hasher::HASH_NAN)

        x = {{ float }}.new(2)
        i = 1
        until x.infinite?
          Crystal::Hasher.reduce_num(x).should eq(1_u64 << (i % 61))
          x *= 2
          i += 1
        end

        x = {{ float }}.new(0.5)
        i = 1
        until x.zero?
          Crystal::Hasher.reduce_num(x).should eq(1_u64 << ((-i) % 61))
          x /= 2
          i += 1
        end
      {% end %}

      Crystal::Hasher.reduce_num(Float32::MAX).should eq(0x1FFF_F800_0000_003F_u64)
      Crystal::Hasher.reduce_num(Float64::MAX).should eq(0x1F00_FFFF_FFFF_FFFF_u64)
    end

    it "reduces BigInt" do
      Crystal::Hasher.reduce_num(0.to_big_i).should eq(0_u64)
      Crystal::Hasher.reduce_num(1.to_big_i).should eq(1_u64)
      Crystal::Hasher.reduce_num((-1).to_big_i).should eq(UInt64::MAX)

      (1..300).each do |i|
        Crystal::Hasher.reduce_num(2.to_big_i ** i).should eq(1_u64 << (i % 61))
        Crystal::Hasher.reduce_num(-(2.to_big_i ** i)).should eq(&-(1_u64 << (i % 61)))
      end
    end

    it "reduces BigFloat" do
      Crystal::Hasher.reduce_num(0.to_big_f).should eq(0_u64)
      Crystal::Hasher.reduce_num(1.to_big_f).should eq(1_u64)
      Crystal::Hasher.reduce_num((-1).to_big_f).should eq(UInt64::MAX)
      Crystal::Hasher.reduce_num(Float32::MAX.to_big_f).should eq(0x1FFF_F800_0000_003F_u64)
      Crystal::Hasher.reduce_num(Float64::MAX.to_big_f).should eq(0x1F00_FFFF_FFFF_FFFF_u64)

      (1..300).each do |i|
        Crystal::Hasher.reduce_num(2.to_big_f ** i).should eq(1_u64 << (i % 61))
        Crystal::Hasher.reduce_num(-(2.to_big_f ** i)).should eq(&-(1_u64 << (i % 61)))
        Crystal::Hasher.reduce_num(0.5.to_big_f ** i).should eq(1_u64 << ((-i) % 61))
        Crystal::Hasher.reduce_num(-(0.5.to_big_f ** i)).should eq(&-(1_u64 << ((-i) % 61)))
      end
    end

    it "reduces BigDecimal" do
      Crystal::Hasher.reduce_num(0.to_big_d).should eq(0_u64)
      Crystal::Hasher.reduce_num(1.to_big_d).should eq(1_u64)
      Crystal::Hasher.reduce_num((-1).to_big_d).should eq(UInt64::MAX)

      # small inverse powers of 10
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 1)).should eq(0x1CCCCCCCCCCCCCCC_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 2)).should eq(0x0FAE147AE147AE14_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 3)).should eq(0x0E5E353F7CED9168_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 4)).should eq(0x14A305532617C1BD_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 5)).should eq(0x05438088509BF9C6_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 6)).should eq(0x06ED2674080F98FA_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 7)).should eq(0x1A4AEA3ECD9B28E5_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 8)).should eq(0x12A1176CAE291DB0_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 9)).should eq(0x01DCE8BE116A82F8_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 10)).should eq(0x1362E41301BDD9E5_u64)

      # a^(p-1) === 1 (mod p)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 0x1FFFFFFFFFFFFFFE_u64)).should eq(1_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 0x1FFFFFFFFFFFFFFD_u64)).should eq(10_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 0x1FFFFFFFFFFFFFFC_u64)).should eq(100_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 0x1FFFFFFFFFFFFFFB_u64)).should eq(1000_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 0x1FFFFFFFFFFFFFFA_u64)).should eq(10000_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 0x1FFFFFFFFFFFFFF9_u64)).should eq(100000_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 0x1FFFFFFFFFFFFFF8_u64)).should eq(1000000_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 0x1FFFFFFFFFFFFFF7_u64)).should eq(10000000_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 0x1FFFFFFFFFFFFFF6_u64)).should eq(100000000_u64)
      Crystal::Hasher.reduce_num(BigDecimal.new(1, 0x1FFFFFFFFFFFFFF5_u64)).should eq(1000000000_u64)

      (1..300).each do |i|
        Crystal::Hasher.reduce_num(2.to_big_d ** i).should eq(1_u64 << (i % 61))
        Crystal::Hasher.reduce_num(-(2.to_big_d ** i)).should eq(&-(1_u64 << (i % 61)))
        Crystal::Hasher.reduce_num(0.5.to_big_d ** i).should eq(1_u64 << ((-i) % 61))
        Crystal::Hasher.reduce_num(-(0.5.to_big_d ** i)).should eq(&-(1_u64 << ((-i) % 61)))
      end
    end

    it "reduces BigRational" do
      Crystal::Hasher.reduce_num(0.to_big_r).should eq(0_u64)
      Crystal::Hasher.reduce_num(1.to_big_r).should eq(1_u64)
      Crystal::Hasher.reduce_num((-1).to_big_r).should eq(UInt64::MAX)

      # inverses of small integers
      Crystal::Hasher.reduce_num(BigRational.new(1, 2)).should eq(0x1000000000000000_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 3)).should eq(0x1555555555555555_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 4)).should eq(0x0800000000000000_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 5)).should eq(0x1999999999999999_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 6)).should eq(0x1AAAAAAAAAAAAAAA_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 7)).should eq(0x1B6DB6DB6DB6DB6D_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 8)).should eq(0x0400000000000000_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 9)).should eq(0x1C71C71C71C71C71_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 10)).should eq(0x1CCCCCCCCCCCCCCC_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 11)).should eq(0x1D1745D1745D1745_u64)

      Crystal::Hasher.reduce_num(BigRational.new(1, 0x1000000000000000_u64)).should eq(2_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 0x1555555555555555_u64)).should eq(3_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 0x0800000000000000_u64)).should eq(4_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 0x1999999999999999_u64)).should eq(5_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 0x1AAAAAAAAAAAAAAA_u64)).should eq(6_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 0x1B6DB6DB6DB6DB6D_u64)).should eq(7_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 0x0400000000000000_u64)).should eq(8_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 0x1C71C71C71C71C71_u64)).should eq(9_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 0x1CCCCCCCCCCCCCCC_u64)).should eq(10_u64)
      Crystal::Hasher.reduce_num(BigRational.new(1, 0x1D1745D1745D1745_u64)).should eq(11_u64)

      (1..300).each do |i|
        Crystal::Hasher.reduce_num(2.to_big_r ** i).should eq(1_u64 << (i % 61))
        Crystal::Hasher.reduce_num(-(2.to_big_r ** i)).should eq(&-(1_u64 << (i % 61)))
        Crystal::Hasher.reduce_num(0.5.to_big_r ** i).should eq(1_u64 << ((-i) % 61))
        Crystal::Hasher.reduce_num(-(0.5.to_big_r ** i)).should eq(&-(1_u64 << ((-i) % 61)))
      end

      Crystal::Hasher.reduce_num(BigRational.new(1, 0x1FFF_FFFF_FFFF_FFFF_u64)).should eq(Crystal::Hasher::HASH_INF_PLUS)
      Crystal::Hasher.reduce_num(BigRational.new(-1, 0x1FFF_FFFF_FFFF_FFFF_u64)).should eq(Crystal::Hasher::HASH_INF_MINUS)
      Crystal::Hasher.reduce_num(BigRational.new(2, 0x1FFF_FFFF_FFFF_FFFF_u64)).should eq(Crystal::Hasher::HASH_INF_PLUS)
      Crystal::Hasher.reduce_num(BigRational.new(-2, 0x1FFF_FFFF_FFFF_FFFF_u64)).should eq(Crystal::Hasher::HASH_INF_MINUS)
    end
  end
end
