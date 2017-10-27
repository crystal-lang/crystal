require "spec"
require "bit_array"
require "random/secure"

struct Crystal::Hasher
  def initialize(a, b : UInt64)
    @hasher = FunnyHash64.new(a, b)
  end

  def self.for_test
    new(1_u64, 1_u64)
  end
end

enum TestHasherEnum
  A
  B
end

alias THasher = Crystal::Hasher

describe "Crystal::Hasher" do
  context "behavior" do
    it "#nil should change hasher state" do
      hasher = THasher.for_test
      hasher1 = nil.hash(hasher)
      hasher2 = nil.hash(hasher1)
      hasher1.result.should_not eq(hasher.result)
      hasher2.result.should_not eq(hasher.result)
      hasher2.result.should_not eq(hasher1.result)
    end

    it "#bool should change state and differ" do
      hasher = THasher.for_test
      hasher_true = true.hash(hasher)
      hasher_false = false.hash(hasher)
      hasher.result.should_not eq(hasher_true.result)
      hasher.result.should_not eq(hasher_false.result)
      hasher_true.result.should_not eq(hasher_false.result)
    end

    it "#int should change state and differ" do
      hasher = THasher.for_test
      hasher1 = 1.hash(hasher)
      hasher2 = 2.hash(hasher)
      hasher12 = 2.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each do |(a, b)|
        a.should_not eq(b)
      end
    end

    it "#int should be equal for different types" do
      1.hash.should eq(1_u64.hash)
      2.hash.should eq(2_u64.hash)
    end

    it "#float should change state and differ" do
      hasher = THasher.for_test
      hasher1 = 1.0.hash(hasher)
      hasher2 = 2.0.hash(hasher)
      hasher12 = 2.0.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each do |(a, b)|
        a.should_not eq(b)
      end
    end

    it "#char should change state and differ" do
      hasher = THasher.for_test
      hasher1 = 'a'.hash(hasher)
      hasher2 = 'b'.hash(hasher)
      hasher12 = 'b'.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each do |(a, b)|
        a.should_not eq(b)
      end
    end

    it "#enum should change state and differ" do
      hasher = THasher.for_test
      hasher1 = TestHasherEnum::A.hash(hasher)
      hasher2 = TestHasherEnum::B.hash(hasher)
      hasher12 = TestHasherEnum::B.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each do |(a, b)|
        a.should_not eq(b)
      end
    end

    it "#symbol should change state and differ" do
      hasher = THasher.for_test
      hasher1 = :A.hash(hasher)
      hasher2 = :B.hash(hasher)
      hasher12 = :B.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each do |(a, b)|
        a.should_not eq(b)
      end
    end

    it "#reference should change state and differ" do
      hasher = THasher.for_test
      a, b = Reference.new, Reference.new
      hasher1 = a.hash(hasher)
      hasher2 = b.hash(hasher)
      hasher12 = b.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each do |(a, b)|
        a.should_not eq(b)
      end
    end

    it "#string should change state and differ" do
      hasher = THasher.for_test
      hasher1 = "a".hash(hasher)
      hasher2 = "b".hash(hasher)
      hasher12 = "b".hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each do |(a, b)|
        a.should_not eq(b)
      end
    end

    it "#class should change state and differ" do
      hasher = THasher.for_test
      hasher1 = THasher.hash(hasher)
      hasher2 = TestHasherEnum.hash(hasher)
      hasher12 = TestHasherEnum.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each do |(a, b)|
        a.should_not eq(b)
      end
    end

    it "#bytes should change state and differ" do
      hasher = THasher.for_test
      a = Bytes[1, 2, 3]
      b = Bytes[2, 3, 4]
      hasher1 = a.hash(hasher)
      hasher2 = b.hash(hasher)
      hasher12 = b.hash(hasher1)
      [hasher, hasher1, hasher2, hasher12]
        .map(&.result)
        .combinations(2)
        .each do |(a, b)|
        a.should_not eq(b)
      end
    end
  end

  context "funny_hash" do
    it "result should work" do
      hasher = THasher.new(1_u64, 1_u64)
      typeof(hasher.result).should eq(UInt64)
      hasher.result.should eq(0x162c591a100060e5_u64)

      hasher = THasher.new(1_u64, 2_u64)
      hasher.result.should eq(0x7f8304f0947082d1_u64)

      hasher = THasher.new(2_u64, 1_u64)
      hasher.result.should eq(0xc302065c9b909fdf_u64)

      hasher = THasher.new(0x123456789abcdef0_u64, 0x016fcd2b89e745a3_u64)
      hasher.result.should eq(0x54258afe17b6a4bb_u64)

      # "bad seed"
      hasher = THasher.new(0_u64, 0_u64)
      hasher.result.should eq(0_u64)
    end

    it "#nil should match test vectors" do
      hasher = THasher.for_test
      hasher1 = nil.hash(hasher)
      hasher2 = nil.hash(hasher1)
      hasher1.result.should eq(0x2c58b2332000c1cb_u64)
      hasher2.result.should eq(0xef5ab89129b8991b_u64)
    end

    it "#bool should match test vectors" do
      hasher = THasher.for_test
      hasher_true = true.hash(hasher)
      hasher_false = false.hash(hasher)
      hasher_true.result.should eq(0x94e4534c12903881_u64)
      hasher_false.result.should eq(0x15cf71e56618745b_u64)
    end

    it "#int should match test vectors" do
      hasher = THasher.for_test
      hasher1 = 1.hash(hasher)
      hasher2 = 2.hash(hasher)
      hasher1.result.should eq(0x94e4534c12903881_u64)
      hasher2.result.should eq(0xaf42909720d981e7_u64)
    end

    it "#float should match test vectors" do
      hasher = THasher.for_test
      hasher1 = 1.0.hash(hasher)
      hasher2 = 2.0.hash(hasher)
      hasher1.result.should eq(0xecfbe7798e8f67f2_u64)
      hasher2.result.should eq(0x72847386c9572c30_u64)
    end

    it "#string should match test vectors" do
      hasher = THasher.for_test
      hasher0 = "".hash(hasher)
      hasher1 = "1".hash(hasher)
      hasher2 = "2.0".hash(hasher)
      puts "#{hasher0.result.to_s(16)}"
      puts "#{hasher1.result.to_s(16)}"
      puts "#{hasher2.result.to_s(16)}"
      hasher0.result.should eq(0x15cf71e56618745b_u64)
      hasher1.result.should eq(0x70ef623beff8c213_u64)
      hasher2.result.should eq(0x2908fdd2bb81fbed_u64)
    end
  end
end
