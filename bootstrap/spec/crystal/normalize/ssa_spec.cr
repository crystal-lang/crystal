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

  it "performs ssa on if without else" do
    assert_normalize "a = 1; if true; a = 2; end; a", "a = 1\nif true\n  #temp_1 = a:1 = 2\n  a:2 = a:1\n  #temp_1\nelse\n  a:2 = a\n  nil\nend\na:2"
  end

  it "performs ssa on if without then" do
    assert_normalize "a = 1; if true; else; a = 2; end; a", "a = 1\nif true\n  a:2 = a\n  nil\nelse\n  #temp_1 = a:1 = 2\n  a:2 = a:1\n  #temp_1\nend\na:2"
  end

  it "performs ssa on if" do
    assert_normalize "a = 1; if true; a = 2; else; a = 3; end; a", "a = 1\nif true\n  #temp_1 = a:1 = 2\n  a:3 = a:1\n  #temp_1\nelse\n  #temp_2 = a:2 = 3\n  a:3 = a:2\n  #temp_2\nend\na:3"
  end

  it "performs ssa on if assigns many times on then" do
    assert_normalize "a = 1; if true; a = 2; a = 3; a = 4; else; a = 5; end; a",
      "a = 1\nif true\n  #temp_1 = begin\n    a:1 = 2\n    a:2 = 3\n    a:3 = 4\n  end\n  a:5 = a:3\n  #temp_1\nelse\n  #temp_2 = a:4 = 5\n  a:5 = a:4\n  #temp_2\nend\na:5"
  end

  it "performs ssa on if assigns many times on else" do
    assert_normalize "a = 1; if true; a = 5; else; a = 2; a = 3; a = 4; end; a",
      "a = 1\nif true\n  #temp_1 = a:1 = 5\n  a:5 = a:1\n  #temp_1\nelse\n  #temp_2 = begin\n    a:2 = 2\n    a:3 = 3\n    a:4 = 4\n  end\n  a:5 = a:4\n  #temp_2\nend\na:5"
  end

  it "performs ssa on if declares var inside then" do
    assert_normalize "if true; a = 1; a = 2; end; a",
      "if true\n  #temp_1 = begin\n    a = 1\n    a:1 = 2\n  end\n  a:2 = a:1\n  #temp_1\nelse\n  a:2 = nil\n  nil\nend\na:2"
  end

  it "performs ssa on if declares var inside then 2" do
    assert_normalize "if true; a = 1; a = 2; else; 1; end; a",
      "if true\n  #temp_1 = begin\n    a = 1\n    a:1 = 2\n  end\n  a:2 = a:1\n  #temp_1\nelse\n  #temp_2 = 1\n  a:2 = nil\n  #temp_2\nend\na:2"
  end

  it "performs ssa on if declares var inside else" do
    assert_normalize "if true; else; a = 1; a = 2; end; a",
      "if true\n  a:2 = nil\n  nil\nelse\n  #temp_1 = begin\n    a = 1\n    a:1 = 2\n  end\n  a:2 = a:1\n  #temp_1\nend\na:2"
  end

  it "performs ssa on if declares var inside else 2" do
    assert_normalize "if true; 1; else; a = 1; a = 2; end; a",
      "if true\n  #temp_1 = 1\n  a:2 = nil\n  #temp_1\nelse\n  #temp_2 = begin\n    a = 1\n    a:1 = 2\n  end\n  a:2 = a:1\n  #temp_2\nend\na:2"
  end

  it "performs ssa on if declares var inside both branches" do
    assert_normalize "if true; a = 1; else; a = 2; end; a",
      "if true\n  #temp_1 = a = 1\n  a:2 = a\n  #temp_1\nelse\n  #temp_2 = a:1 = 2\n  a:2 = a:1\n  #temp_2\nend\na:2"
  end

  it "performs ssa on if don't assign other vars" do
    assert_normalize "a = 1; if true; b = 1; else; b = 2; end\na",
      "a = 1\nif true\n  #temp_1 = b = 1\n  b:2 = b\n  #temp_1\nelse\n  #temp_2 = b:1 = 2\n  b:2 = b:1\n  #temp_2\nend\na"
  end

  it "performs ssa on if with break" do
    assert_normalize "a = 1; if true; a = 2; else; break; end; a", "a = 1\nif true\n  #temp_1 = a:1 = 2\n  a:2 = a:1\n  #temp_1\nelse\n  a:2 = a\n  break\nend\na:2"
  end

  it "performs ssa on block" do
    assert_normalize "a = 1; foo { a = 2; a = a + 1 }; a = a + 1; a",
      "a = 1\nfoo() do\n  #temp_1 = begin\n    a:1 = 2\n    a:2 = a:1 + 1\n  end\n  a = a:2\n  #temp_1\nend\na:3 = a + 1\na:3"
  end
end
