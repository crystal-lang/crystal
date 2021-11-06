{% skip_file unless flag?(:linux) %}

require "spec"
require "syscall"

module Syscall
  def_syscall pipe2, Int32, pipefd : Int32[2]*, flags : Int32
  def_syscall write, Int32, fd : Int32, buf : UInt8*, count : LibC::SizeT
  def_syscall read, Int32, fd : Int32, buf : UInt8*, count : LibC::SizeT
  def_syscall close, Int32, fd : Int32
end

describe Syscall do
  it "can call into the system successfully" do
    pair = uninitialized Int32[2]
    Syscall.pipe2(pointerof(pair), 0).should eq(0)

    str = "Hello"
    Syscall.write(pair[1], str.to_unsafe, LibC::SizeT.new(str.bytesize)).should eq(str.bytesize)

    buf = Bytes.new(64)
    Syscall.read(pair[0], buf.to_unsafe, LibC::SizeT.new(buf.size)).should eq(str.bytesize)

    String.new(buf.to_unsafe, str.bytesize).should eq(str)

    Syscall.close(pair[0]).should eq(0)
    Syscall.close(pair[1]).should eq(0)
  end
end
