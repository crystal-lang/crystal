#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Normalize: array literal" do
  it "normalizes empty with of" do
    assert_expand "[] of Int", "::Array(Int).new"
  end

  it "normalizes non-empty with of" do
    assert_expand "[1, 2] of Int", "#temp_1 = ::Array(Int).new(2)\n#temp_1.length = 2\n#temp_2 = #temp_1.buffer\n#temp_2[0] = 1\n#temp_2[1] = 2\n#temp_1"
  end

  it "normalizes non-empty without of" do
    assert_expand "[1, 2]", "#temp_1 = ::Array(typeof(1, 2)).new(2)\n#temp_1.length = 2\n#temp_2 = #temp_1.buffer\n#temp_2[0] = 1\n#temp_2[1] = 2\n#temp_1"
  end
end
