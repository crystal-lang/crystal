require "spec"

describe "Double" do
  describe "**" do
    assert { expect((2.5 ** 2)).to eq(6.25) }
    assert { expect((2.5 ** 2.5_f32)).to eq(9.882117688026186) }
    assert { expect((2.5 ** 2.5)).to eq(9.882117688026186) }
  end
end
