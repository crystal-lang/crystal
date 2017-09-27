require "../../spec_helper"

describe "Normalize: expressions" do
  it "normalizes an empty expression" do
    assert_normalize "begin\nend", ""
  end

  it "normalizes an expression" do
    assert_normalize "(1 < 2).as(Bool)", "(1 < 2).as(Bool)"
  end

  it "normalizes expressions" do
    assert_normalize "begin\n  1\n  2\nend", "1\n2"
  end
end
