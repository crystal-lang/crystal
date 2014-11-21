require "../../spec_helper"

describe "Normalize: hash literal" do
  it "normalizes empty with of" do
    assert_expand "{} of Int => Float", "::Hash(Int, Float).new"
  end

  it "normalizes non-empty with of" do
    assert_expand "{1 => 2, 3 => 4} of Int => Float", "__temp_1 = ::Hash(Int, Float).new\n__temp_1[1] = 2\n__temp_1[3] = 4\n__temp_1"
  end

  it "normalizes non-empty without of" do
    assert_expand "{1 => 2, 3 => 4}", "__temp_1 = ::Hash(typeof(1, 3), typeof(2, 4)).new\n__temp_1[1] = 2\n__temp_1[3] = 4\n__temp_1"
  end
end
