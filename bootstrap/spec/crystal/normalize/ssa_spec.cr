#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Normalize: ssa" do
  it "performs ssa on simple assignment" do
    assert_normalize "a = 1; a = 2", "a = 1\na:1 = 2"
  end

  it "performs ssa on many simple assignments" do
    assert_normalize "a = 1; a = 2; a = 3", "a = 1\na:1 = 2\na:2 = 3"
  end

  it "performs ssa on read" do
    assert_normalize "a = 1; a = a + 1; a = a + 1", "a = 1\na:1 = a + 1\na:2 = a:1 + 1"
  end
end
