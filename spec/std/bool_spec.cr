require "spec"

describe "Bool" do
  describe "|" do
    assert { expect((false | false)).to be_false }
    assert { expect((false | true)).to be_true }
    assert { expect((true | false)).to be_true }
    assert { expect((true | true)).to be_true }
  end

  describe "&" do
    assert { expect((false & false)).to be_false }
    assert { expect((false & true)).to be_false }
    assert { expect((true & false)).to be_false }
    assert { expect((true & true)).to be_true }
  end

  describe "hash" do
    expect(true.hash).to eq(1)
    expect(false.hash).to eq(0)
  end
end
