require "../../spec_helper"

describe "Normalize: array literal" do
  it "normalizes empty with of" do
    assert_expand "[] of Int", "::Array(Int).new"
  end

  it "normalizes non-empty with of" do
    assert_expand "[1, 2] of Int", "::Array(Int).build(2) do |__temp_1|\n  __temp_1[0] = 1\n  __temp_1[1] = 2\n  2\nend"
  end

  it "normalizes non-empty without of" do
    assert_expand "[1, 2]", "::Array(typeof(1, 2)).build(2) do |__temp_1|\n  __temp_1[0] = 1\n  __temp_1[1] = 2\n  2\nend"
  end
end
