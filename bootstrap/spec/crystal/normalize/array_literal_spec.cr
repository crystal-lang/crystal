#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Normalize: array literal" do
  it "normalizes empty with of" do
    assert_normalize "[] of Int", "::Array(Int).new"
  end

  it "normalizes non-empty with of" do
    assert_normalize "[1, 2] of Int", "#temp_1 = ::Array(Int).new(16)\n#temp_1.length = 2\n(#temp_1.buffer)[0] = 1\n(#temp_1.buffer)[1] = 2\n#temp_1"
  end

  it "normalizes non-empty without of" do
    assert_normalize "[1, 2]", "#temp_1 = ::Array(<type_merge>(1, 2)).new(16)\n#temp_1.length = 2\n(#temp_1.buffer)[0] = 1\n(#temp_1.buffer)[1] = 2\n#temp_1"
  end
end
