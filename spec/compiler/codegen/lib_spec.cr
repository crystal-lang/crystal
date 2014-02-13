#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Code gen: lib" do
  it "codegens lib var set and get" do
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
end
