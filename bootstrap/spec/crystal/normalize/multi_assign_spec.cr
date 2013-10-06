#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Normalize: multi assign" do
  it "normalizes n to n" do
    assert_normalize "a, b, c = 1, 2, 3", "#temp_1 = 1\n#temp_2 = 2\n#temp_3 = 3\na = #temp_1\nb = #temp_2\nc = #temp_3"
  end

  it "normalizes 1 to n" do
    assert_normalize "d = 1\na, b, c = d", "d = 1\n#temp_1 = d\na = #temp_1[0]\nb = #temp_1[1]\nc = #temp_1[2]"
  end
end
