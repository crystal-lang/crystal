require "../../spec_helper"

describe "Normalize: range literal" do
  it "normalizes not exclusive" do
    assert_normalize "1..2", "::Range.new(1, 2, false)"
  end

  it "normalizes exclusive" do
    assert_normalize "1...2", "::Range.new(1, 2, true)"
  end
end
