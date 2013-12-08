#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Normalize: chained comparisons" do
  it "normalizes one comparison with literal" do
    assert_normalize "1 <= 2 <= 3", "if #temp_1 = 1 <= 2\n  2 <= 3\nelse\n  #temp_1\nend"
  end

  it "normalizes one comparison with var" do
    assert_normalize "b = 1; 1 <= b <= 3", "b = 1\nif #temp_1 = 1 <= b\n  b <= 3\nelse\n  #temp_1\nend"
  end

  it "normalizes one comparison with call" do
    assert_normalize "1 <= b <= 3", "if #temp_2 = 1 <= #temp_1 = b()\n  #temp_1 <= 3\nelse\n  #temp_2\nend"
  end

  it "normalizes two comparisons with literal" do
    assert_normalize "1 <= 2 <= 3 <= 4", "if #temp_2 = if #temp_1 = 1 <= 2\n  2 <= 3\nelse\n  #temp_1\nend\n  3 <= 4\nelse\n  #temp_2\nend"
  end

  it "normalizes two comparisons with calls" do
    assert_normalize "1 <= a <= b <= 4", "if #temp_4 = if #temp_3 = 1 <= #temp_2 = a()\n  #temp_2 <= #temp_1 = b()\nelse\n  #temp_3\nend\n  #temp_1 <= 4\nelse\n  #temp_4\nend"
  end
end
