require "../../spec_helper"

describe "Normalize: until" do
  it "normalizes until" do
    assert_normalize "until 1; 2; end", "while !1\n  2\nend"
  end
end
