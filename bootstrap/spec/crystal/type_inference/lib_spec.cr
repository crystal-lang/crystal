#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: lib" do
  it "raises on undefined fun" do
    assert_error("lib C; end; C.foo", "undefined fun 'foo' for C")
  end

  it "raises wrong number of arguments" do
    assert_error("lib C; fun foo : Int32; end; C.foo 1", "wrong number of arguments for 'C#foo' (1 for 0)")
  end

  it "raises wrong argument type" do
    assert_error("lib C; fun foo(x : Int32) : Int32; end; C.foo 1.5", "argument 'x' of 'C#foo' must be Int32, not Float64")
  end
end
