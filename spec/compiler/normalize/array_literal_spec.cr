require "../../spec_helper"

describe "Normalize: array literal" do
  it "normalizes empty with of" do
    assert_expand "[] of Int", "::Array(Int).new"
  end

  it "normalizes non-empty with of" do
    assert_expand "[1, 2] of Int8", <<-CR
      __temp_1 = ::Array(Int8).unsafe_build(2)
      __temp_2 = __temp_1.to_unsafe
      __temp_2[0] = 1
      __temp_2[1] = 2
      __temp_1
      CR
  end

  it "normalizes non-empty without of" do
    assert_expand "[1, 2]", <<-CR
      __temp_1 = ::Array(typeof(1, 2)).unsafe_build(2)
      __temp_2 = __temp_1.to_unsafe
      __temp_2[0] = 1
      __temp_2[1] = 2
      __temp_1
      CR
  end
end
