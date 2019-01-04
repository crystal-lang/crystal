require "../../spec_helper"

describe "Code gen: convert primitives" do
  describe "to_*!" do
    it "works from negative values to unsigned types" do
      run(%(
        -1.to_u! == 4294967295_u32
      )).to_b.should be_true
    end

    it "works from greater values to smaller types" do
      run(%(
        47866.to_i8! == -6_i8
      )).to_b.should be_true
    end

    it "preserves negative sign" do
      run(%(
        -1_i8.to_i! == -1_i32
      )).to_b.should be_true
    end
  end
end
