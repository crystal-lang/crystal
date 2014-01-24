#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Normalize: or" do
  it "normalizes or without variable" do
    assert_normalize "a || b", "if #temp_1 = a()\n  #temp_1\nelse\n  b()\nend"
  end

  it "normalizes or with variable on the left" do
    assert_normalize "a = 1; a || b", "a = 1\nif a\n  a\nelse\n  b()\nend"
  end
end
