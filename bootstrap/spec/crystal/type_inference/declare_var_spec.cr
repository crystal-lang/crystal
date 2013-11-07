#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: declare var" do
  it "types declare var" do
    assert_type("a :: Int32") { int32 }
  end

  it "types declare var and reads it" do
    assert_type("a :: Int32; a") { int32 }
  end

  it "types declare var and changes its type" do
    assert_type("a :: Int32; while 1 == 2; a = 'a'; end; a") { union_of(int32, char) }
  end
end
