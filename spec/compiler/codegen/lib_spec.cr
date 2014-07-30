#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Code gen: lib" do
  pending "codegens lib var set and get" do
    run("
      lib C
        $errno : Int32
      end

      C.errno = 1
      C.errno
      ").to_i.should eq(1)
  end

  it "call to void function" do
    run("
      lib C
        fun srandom(x : UInt32) : Void
      end

      def foo
        C.srandom(0_u32)
      end

      foo
    ")
  end

  it "allows passing type to C if it has a coverter with to_unsafe" do
    build("
      lib C
        fun foo(x : Int32) : Int32
      end

      class Foo
        def to_unsafe
          1
        end
      end

      C.foo Foo.new
      ")
  end

  it "allows passing type to C if it has a coverter with to_unsafe (bug)" do
    build(%(
      require "prelude"

      lib C
        fun foo(x : UInt8*)
      end

      def foo
        yield 1
      end

      C.foo(foo &.to_s)
      ))
  end

  it "allows setting/getting external variable as function pointer" do
    build(%(
      require "prelude"

      lib C
        $x : ->
      end

      C.x = ->{}
      C.x.call
      ))
  end
end
