{% skip_file unless flag?(:linux) %}

require "spec"
require "syscall"

private Syscall.def_syscall pipe2, Int32, pipefd : Int32[2]*, flags : Int32
private Syscall.def_syscall write, Int32, fd : Int32, buf : UInt8*, count : LibC::SizeT
private Syscall.def_syscall read, Int32, fd : Int32, buf : UInt8*, count : LibC::SizeT
private Syscall.def_syscall close, Int32, fd : Int32

describe Syscall do
  it "can call into the system successfully" do
    pair = uninitialized Int32[2]
    pipe2(pointerof(pair), 0).should eq(0)

    str = "Hello"
    write(pair[1], str.to_unsafe, LibC::SizeT.new(str.bytesize)).should eq(str.bytesize)

    buf = Bytes.new(64)
    read(pair[0], buf.to_unsafe, LibC::SizeT.new(buf.size)).should eq(str.bytesize)

    String.new(buf.to_unsafe, str.bytesize).should eq(str)

    close(pair[0]).should eq(0)
    close(pair[1]).should eq(0)
  end
end
