require "../../spec_helper"

describe "Normalize: range literal" do
  it "normalizes not exclusive" do
    assert_expand "1..2", "::Range.new(1, 2, false)"
  end
end
