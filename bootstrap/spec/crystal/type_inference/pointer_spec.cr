#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: pointer" do
  it "types int pointer" do
    assert_type("a = 1; a.ptr") { pointer_of(int32) }
  end

  # it "types pointer value" do
  #   assert_type("a = 1; b = a.ptr; b.value") { int32 }
  # end

  # it "types pointer add" do
  #   assert_type("a = 1; a.ptr + 1_i64") { pointer_of(int32) }
  # end

  # it "types pointer diff" do
  #   assert_type("a = 1; b = 2; a.ptr - b.ptr") { int64 }
  # end

  it "types Pointer.malloc" do
    assert_type("Pointer(Int32).malloc(10_u64)") { pointer_of(int32) }
  end
end
