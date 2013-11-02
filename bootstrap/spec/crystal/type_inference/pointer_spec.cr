#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: pointer" do
  it "types int pointer" do
    assert_type("a = 1; a.ptr") { pointer_of(int32) }
  end

  it "types pointer value" do
    assert_type("a = 1; b = a.ptr; b.value") { int32 }
  end

  it "types pointer add" do
    assert_type("a = 1; a.ptr + 1_i64") { pointer_of(int32) }
  end

  it "types pointer address" do
    assert_type("a = 1; b = a.ptr; b.address") { uint64 }
  end

  it "types Pointer.malloc" do
    assert_type("Pointer(Int32).malloc(10_u64)") { pointer_of(int32) }
  end

  it "types Pointer.new" do
    assert_type("Pointer(Int32).new(10_u64)") { pointer_of(int32) }
  end

  it "reports can only get pointer of variable" do
    assert_syntax_error "a.ptr",
      "can only get 'ptr' of variable or instance variable"
  end

  it "reports wrong number of arguments for ptr" do
    assert_syntax_error "a = 1; a.ptr 1",
      "wrong number of arguments for 'ptr' (1 for 0)"
  end

  it "reports ptr can't receive a block" do
    assert_syntax_error "a = 1; a.ptr {}",
      "'ptr' can't receive a block"
  end

  it "can't do Pointer.malloc without type var" do
    assert_error "
      Pointer.malloc(1_u64)
    ", "can't malloc pointer without type, use Pointer(Type).malloc(size)"
  end
end
