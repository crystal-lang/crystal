require "spec"

describe "Expect Syntax" do
  it "constructs a new instance targetting the given argument" do
    expect(expect(7).target).to eq(7)
  end

  it "constructs a new instance targetting the value of the given block" do
    block = ->{ 1 }
    expect(expect(&block).target).to eq(1)
  end

  it "can be passed nil" do
    expect(expect(nil).target).to be_nil
  end

  it "passes a valid positive expectation" do
    expect(5).to eq(5)
  end

  it "passes a valid negative expectation" do
    expect(5).not_to eq(4)
  end

  it "passes a valid negative expectation with a split infinitive" do
    expect(5).to_not eq(4)
  end

  it "fails an invalid positive expectation" do
    expect_raises(Spec::AssertionFailed, /expected: 4.+got: 5/m) do
      expect(5).to eq(4)
    end
  end

  it "fails an invalid negative expectation" do
    expect_raises(Spec::AssertionFailed, /expected: actual_value != 5.+got: 5/m) do
      expect(5).to_not eq(5)
    end
  end

  context "when passed a block" do
    it "passes a valid positive expectation" do
      expect { 5 }.to eq(5)
    end
  end
end
