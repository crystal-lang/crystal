#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Normalize: multi assign" do
  it "normalizes n to n" do
    assert_normalize "a, b, c = 1, 2, 3", "#temp_1 = 1\n#temp_2 = 2\n#temp_3 = 3\na = #temp_1\nb = #temp_2\nc = #temp_3"
  end

  it "normalizes 1 to n" do
    assert_normalize "d = 1\na, b, c = d", "d = 1\n#temp_1 = d\na = #temp_1[0]\nb = #temp_1[1]\nc = #temp_1[2]"
  end

  it "normalizes n to 1" do
    assert_normalize "a = 1, 2", "a = begin\n  #temp_1 = ::Array(<type_merge>(1, 2)).new(16)\n  #temp_1.length = 2\n  #temp_2 = #temp_1.buffer\n  #temp_2[0] = 1\n  #temp_2[1] = 2\n  #temp_1\nend"
  end

  it "normalizes n to n with []" do
    assert_normalize "a = 1; b = 2; a[0], b[1] = 2, 3", "a = 1\nb = 2\n#temp_1 = 2\n#temp_2 = 3\na[0] = #temp_1\nb[1] = #temp_2"
  end

  it "normalizes 1 to n with []" do
    assert_normalize "a = 1; b = 2; a[0], b[1] = 2", "a = 1\nb = 2\n#temp_1 = 2\na[0] = #temp_1[0]\nb[1] = #temp_1[1]"
  end

  it "normalizes n to 1 with []" do
    assert_normalize "a = 1; a[0] = 1, 2, 3","a = 1\na[0] = #temp_1 = ::Array(<type_merge>(1, 2, 3)).new(16)\n#temp_1.length = 3\n#temp_2 = #temp_1.buffer\n#temp_2[0] = 1\n#temp_2[1] = 2\n#temp_2[2] = 3\n#temp_1"
  end

  it "normalizes n to n with call" do
    assert_normalize "a = 1; b = 2; a.foo, b.bar = 2, 3", "a = 1\nb = 2\n#temp_1 = 2\n#temp_2 = 3\na.foo = #temp_1\nb.bar = #temp_2"
  end

  it "normalizes 1 to n with call" do
    assert_normalize "a = 1; b = 2; a.foo, b.bar = 2", "a = 1\nb = 2\n#temp_1 = 2\na.foo = #temp_1[0]\nb.bar = #temp_1[1]"
  end

  it "normalizes n to 1 with call" do
    assert_normalize "a = 1; a.foo = 1, 2, 3","a = 1\na.foo = #temp_1 = ::Array(<type_merge>(1, 2, 3)).new(16)\n#temp_1.length = 3\n#temp_2 = #temp_1.buffer\n#temp_2[0] = 1\n#temp_2[1] = 2\n#temp_2[2] = 3\n#temp_1"
  end
end
