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

  it "allows passing wrapper struct to c" do
    build("
      lib C
        fun foo(x : Void*) : Int32
      end

      struct Wrapper
        def initialize(@x)
        end
      end

      w = Wrapper.new(Pointer(Void).new(0_u64))
      C.foo(w)
      ")
  end

  it "allows passing pointer wrapper struct to c" do
    build("
      lib C
        fun foo(x : Void**) : Int32
      end

      struct Wrapper
        def initialize(@x)
        end
      end

      w = Wrapper.new(Pointer(Void).new(0_u64))
      p = Pointer(Wrapper).new(0_u64)
      C.foo(p)
      ")
  end
end
