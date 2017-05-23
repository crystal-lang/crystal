require "spec"

enum AtomicEnum
  One
  Two
  Three
end

@[Flags]
enum AtomicEnumFlags
  One
  Two
  Three
end

describe Atomic do
  it "compares and sets with integer" do
    atomic = Atomic.new(1)

    atomic.compare_and_set(2, 3).should eq({1, false})
    atomic.get.should eq(1)

    atomic.compare_and_set(1, 3).should eq({1, true})
    atomic.get.should eq(3)
  end

  it "compares and set with enum" do
    atomic = Atomic(AtomicEnum).new(AtomicEnum::One)

    atomic.compare_and_set(AtomicEnum::Two, AtomicEnum::Three).should eq({AtomicEnum::One, false})
    atomic.get.should eq(AtomicEnum::One)

    atomic.compare_and_set(AtomicEnum::One, AtomicEnum::Three).should eq({AtomicEnum::One, true})
    atomic.get.should eq(AtomicEnum::Three)
  end

  it "compares and set with flags enum" do
    atomic = Atomic(AtomicEnumFlags).new(AtomicEnumFlags::One)

    atomic.compare_and_set(AtomicEnumFlags::Two, AtomicEnumFlags::Three).should eq({AtomicEnumFlags::One, false})
    atomic.get.should eq(AtomicEnumFlags::One)

    atomic.compare_and_set(AtomicEnumFlags::One, AtomicEnumFlags::Three).should eq({AtomicEnumFlags::One, true})
    atomic.get.should eq(AtomicEnumFlags::Three)
  end

  it "compares and sets with nilable type" do
    atomic = Atomic(String?).new(nil)
    string = "hello"

    atomic.compare_and_set(string, "foo").should eq({nil, false})
    atomic.get.should be_nil

    atomic.compare_and_set(nil, string).should eq({nil, true})
    atomic.get.should be(string)

    atomic.compare_and_set(string, nil).should eq({string, true})
    atomic.get.should be_nil
  end

  it "compares and sets with reference type" do
    str1 = "hello"
    str2 = "bye"

    atomic = Atomic(String).new(str1)

    atomic.compare_and_set(str2, "foo").should eq({str1, false})
    atomic.get.should eq(str1)

    atomic.compare_and_set(str1, str2).should eq({str1, true})
    atomic.get.should be(str2)

    atomic.compare_and_set(str2, str1).should eq({str2, true})
    atomic.get.should be(str1)
  end

  it "#adds" do
    atomic = Atomic.new(1)
    atomic.add(2).should eq(1)
    atomic.get.should eq(3)
  end

  it "#sub" do
    atomic = Atomic.new(1)
    atomic.sub(2).should eq(1)
    atomic.get.should eq(-1)
  end

  it "#and" do
    atomic = Atomic.new(5)
    atomic.and(3).should eq(5)
    atomic.get.should eq(1)
  end

  it "#nand" do
    atomic = Atomic.new(5)
    atomic.nand(3).should eq(5)
    atomic.get.should eq(-2)
  end

  it "#or" do
    atomic = Atomic.new(5)
    atomic.or(2).should eq(5)
    atomic.get.should eq(7)
  end

  it "#xor" do
    atomic = Atomic.new(5)
    atomic.xor(3).should eq(5)
    atomic.get.should eq(6)
  end

  it "#max with signed" do
    atomic = Atomic.new(5)
    atomic.max(2).should eq(5)
    atomic.get.should eq(5)
    atomic.max(10).should eq(5)
    atomic.get.should eq(10)
  end

  it "#max with unsigned" do
    atomic = Atomic.new(5_u32)
    atomic.max(2_u32).should eq(5_u32)
    atomic.get.should eq(5_u32)
    atomic.max(UInt32::MAX).should eq(5_u32)
    atomic.get.should eq(UInt32::MAX)
  end

  it "#min with signed" do
    atomic = Atomic.new(5)
    atomic.min(10).should eq(5)
    atomic.get.should eq(5)
    atomic.min(2).should eq(5)
    atomic.get.should eq(2)
  end

  it "#min with unsigned" do
    atomic = Atomic.new(UInt32::MAX)
    atomic.min(10_u32).should eq(UInt32::MAX)
    atomic.get.should eq(10_u32)
    atomic.min(15_u32).should eq(10_u32)
    atomic.get.should eq(10_u32)
  end

  it "#set" do
    atomic = Atomic.new(1)
    atomic.set(2).should eq(2)
    atomic.get.should eq(2)
  end

  it "#set with nil (#4062)" do
    atomic = Atomic(String?).new(nil)

    atomic.set("foo")
    atomic.get.should eq("foo")

    atomic.set(nil)
    atomic.get.should eq(nil)
  end

  it "#lazy_set" do
    atomic = Atomic.new(1)
    atomic.lazy_set(2).should eq(2)
    atomic.get.should eq(2)
  end

  it "#swap" do
    atomic = Atomic.new(1)
    atomic.swap(2).should eq(1)
    atomic.get.should eq(2)
  end
end
