require "spec"

describe "UInt" do
  it "compares with <=>" do
    (1_u32 <=> 0_u32).should eq(1)
    (0_u32 <=> 0_u32).should eq(0)
    (0_u32 <=> 1_u32).should eq(-1)
  end
end
