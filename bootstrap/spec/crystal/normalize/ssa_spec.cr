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

  it "performs ssa on if with empty then" do
    assert_normalize "a = 1; if true; 1; end; a", "a = 1\nif true\n  1\nend\na"
  end

  it "performs ssa on if with empty else" do
    assert_normalize "a = 1; if true; else; 1; end; a", "a = 1\nif true\nelse\n  1\nend\na"
  end
end
