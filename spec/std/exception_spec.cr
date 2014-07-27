#!/usr/bin/env bin/crystal --run
require "spec"

describe "Exception" do
  module ModuleWithLooooooooooooooooooooooooooooooooooooooooooooooongName
    def self.foo
      raise "Foo"
    end
  end

  it "allocates enough space for backtrace frames" do
    begin
      ModuleWithLooooooooooooooooooooooooooooooooooooooooooooooongName.foo
    rescue ex
      ex.backtrace.any? {|x| x.includes? "ModuleWithLooooooooooooooooooooooooooooooooooooooooooooooongName" }.should be_true
    end
  end

  it "unescapes linux backtrace" do
    frame = "_2A_Crystal_3A__3A_Compiler_23_compile_3C_Crystal_3A__3A_Compiler_3E__3A_Nil"
    fixed = "\x2ACrystal\x3A\x3ACompiler\x23compile\x3CCrystal\x3A\x3ACompiler\x3E\x3ANil"
    Exception.unescape_linux_backtrace_frame(frame).should eq(fixed)
  end
end
