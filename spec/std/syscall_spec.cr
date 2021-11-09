{% skip_file unless flag?(:linux) %}

require "spec"
require "syscall"

private module TestSyscall
  Syscall.def_syscall pipe2, Int32, pipefd : Int32[2]*, flags : Int32
  Syscall.def_syscall write, Int32, fd : Int32, buf : UInt8*, count : LibC::SizeT
  Syscall.def_syscall read, Int32, fd : Int32, buf : UInt8*, count : LibC::SizeT
  Syscall.def_syscall close, Int32, fd : Int32
end

describe Syscall do
  it "can call into the system successfully" do
    pair = uninitialized Int32[2]
    TestSyscall.pipe2(pointerof(pair), 0).should eq(0)

    str = "Hello"
    TestSyscall.write(pair[1], str.to_unsafe, LibC::SizeT.new(str.bytesize)).should eq(str.bytesize)

    buf = Bytes.new(64)
    TestSyscall.read(pair[0], buf.to_unsafe, LibC::SizeT.new(buf.size)).should eq(str.bytesize)

    String.new(buf.to_unsafe, str.bytesize).should eq(str)

    TestSyscall.close(pair[0]).should eq(0)
    TestSyscall.close(pair[1]).should eq(0)
  end
end
