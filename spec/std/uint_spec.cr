require "spec"

describe "UInt" do
  it "compares with <=>" do
    (1_u32 <=> 0_u32).gt?.should be_true
    (0_u32 <=> 0_u32).eq?.should be_true
    (0_u32 <=> 1_u32).lt?.should be_true
  end
end
