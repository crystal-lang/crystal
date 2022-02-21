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
end
