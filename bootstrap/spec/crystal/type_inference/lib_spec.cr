#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: lib" do
  it "types a varargs external" do
    assert_type("lib Foo; fun bar(x : Int32, ...) : Int32; end; Foo.bar(1, 1.5, 'a')") { int32 }
  end

  it "raises on undefined fun" do
    assert_error("lib C; end; C.foo", "undefined fun 'foo' for C")
  end

  it "raises wrong number of arguments" do
    assert_error("lib C; fun foo : Int32; end; C.foo 1", "wrong number of arguments for 'C#foo' (1 for 0)")
  end

  it "raises wrong argument type" do
    assert_error("lib C; fun foo(x : Int32) : Int32; end; C.foo 1.5", "argument 'x' of 'C#foo' must be Int32, not Float64")
  end

  it "reports error on fun argument type not primitive like" do
    assert_error "lib Foo; fun foo(x : Reference); end",
      "only primitive types"
  end

  it "reports error on fun return type not primitive like" do
    assert_error "lib Foo; fun foo : Reference; end",
      "only primitive types"
  end

  it "reports error on struct field type not primitive like" do
    assert_error "lib Foo; struct Foo; x : Reference; end; end",
      "only primitive types"
  end

  it "reports error on typedef type not primitive like" do
    assert_error "lib Foo; type Foo : Reference; end",
      "only primitive types"
  end

  it "reports error out can only be used with lib funs" do
    assert_error "foo(out x)",
      "out can only be used with lib funs"
  end

  it "reports redefinition of fun with different signature" do
    assert_error "
      lib C
        fun foo : Int32
        fun foo : Int64
      end
      ",
      "fun redefinition with different signature"
  end

  it "types lib var get" do
    assert_type("
      lib C
        $errno : Int32
      end

      C.errno
      ") { int32 }
  end

  it "types lib var set" do
    assert_type("
      lib C
        $errno : Int32
      end

      C.errno = 1
      ") { int32 }
  end
end
