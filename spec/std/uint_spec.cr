require "spec"

describe "UInt" do
  it "compares with <=>" do
    (1_u32 <=> 0_u32).should eq(1)
    (0_u32 <=> 0_u32).should eq(0)
    (0_u32 <=> 1_u32).should eq(-1)
  end

  describe "&-" do
    it "returns the wrapped negation" do
      x = &-0_u32
      x.should eq(0_u32)
      x.should be_a(UInt32)

      x = &-100_u8
      x.should eq(156_u8)
      x.should be_a(UInt8)

      x = &-1_u8
      x.should eq(255_u8)
      x.should be_a(UInt8)

      x = &-255_u8
      x.should eq(1_u8)
      x.should be_a(UInt8)

      x = &-1_u16
      x.should eq(65535_u16)
      x.should be_a(UInt16)

      x = &-65535_u16
      x.should eq(1_u16)
      x.should be_a(UInt16)

      x = &-1_u32
      x.should eq(4294967295_u32)
      x.should be_a(UInt32)

      x = &-4294967295_u32
      x.should eq(1_u32)
      x.should be_a(UInt32)

      x = &-1_u64
      x.should eq(18446744073709551615_u64)
      x.should be_a(UInt64)

      x = &-18446744073709551615_u64
      x.should eq(1_u64)
      x.should be_a(UInt64)

      x = &-1_u128
      x.should eq(UInt128::MAX) # TODO: Change to literal once supported
      x.should be_a(UInt128)

      x = &-(UInt128::MAX) # TODO: Change to literal once supported
      x.should eq(1_u128)
      x.should be_a(UInt128)
    end
  end
end
