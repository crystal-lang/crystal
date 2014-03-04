#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: tuples" do
  it "types tuple of one element" do
    assert_type("{1}") { tuple_of([int32] of Type | ASTNode) }
  end

  it "types tuple of three elements" do
    assert_type("{1, 2.5, 'a'}") { tuple_of([int32, float64, char] of Type | ASTNode) }
  end

  it "types tuple of one element and then two elements" do
    assert_type("{1}; {1, 2}") { tuple_of([int32, int32] of Type | ASTNode) }
  end

  it "types tuple length" do
    assert_type("{1, 2}.length") { int32 }
  end

  it "types tuple [0]" do
    assert_type("{1, 'a'}[0]") { int32 }
  end

  it "types tuple [1]" do
    assert_type("{1, 'a'}[1]") { char }
  end

  it "types tuple [i]" do
    assert_type("x = 1; {1, 'a'}[x]") { union_of(int32, char) }
  end

  it "gives error when indexing out of range" do
    assert_error "{1, 'a'}[2]",
      "index out of bounds for tuple {Int32, Char}"
  end
end
