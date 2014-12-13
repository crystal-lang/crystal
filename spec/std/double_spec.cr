require "spec"

describe "Double" do
  describe "**" do
    assert { (2.5 ** 2).should eq(6.25) }
    assert { (2.5 ** 2.5_f32).should eq(9.882117688026186) }
    assert { (2.5 ** 2.5).should eq(9.882117688026186) }
  end
end
