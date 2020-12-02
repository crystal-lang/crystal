require "../../spec_helper"

describe "Normalize: array literal" do
  it "normalizes empty with of" do
    assert_expand "[] of Int", "::Array(Int).new"
  end

  it "normalizes non-empty with of" do
    assert_expand "[1, 2] of Int", "__temp_1 = ::Array(Int).new(2)\n__temp_1.to_unsafe[0] = 1\n__temp_1.to_unsafe[1] = 2\n__temp_1.size = 2\n__temp_1"
  end

  it "normalizes non-empty without of" do
    assert_expand "[1, 2]", "__temp_1 = ::Array(typeof(1, 2)).new(2)\n__temp_1.to_unsafe[0] = 1\n__temp_1.to_unsafe[1] = 2\n__temp_1.size = 2\n__temp_1"
  end
end
