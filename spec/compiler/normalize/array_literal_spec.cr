require "../../spec_helper"

describe "Normalize: array literal" do
  it "normalizes empty with of" do
    assert_expand "[] of Int", "::Array(Int).new"
  end

  it "normalizes non-empty with of" do
    assert_expand "[1, 2] of Int8", <<-CR
      __temp_1 = ::Array(Int8).new(2, __temp_2 = uninitialized Int8)
      __temp_1.to_unsafe[0] = 1
      __temp_1.to_unsafe[1] = 2
      __temp_1
      CR
  end

  it "normalizes non-empty without of" do
    assert_expand "[1, 2]", <<-CR
      __temp_1 = ::Array(typeof(1, 2)).new(2, __temp_2 = uninitialized typeof(1, 2))
      __temp_1.to_unsafe[0] = 1
      __temp_1.to_unsafe[1] = 2
      __temp_1
      CR
  end
end
