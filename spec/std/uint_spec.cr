require "spec"

describe "UInt" do
  it "compares with <=>" do
    expect((1_u32 <=> 0_u32)).to eq(1)
    expect((0_u32 <=> 0_u32)).to eq(0)
    expect((0_u32 <=> 1_u32)).to eq(-1)
  end
end
