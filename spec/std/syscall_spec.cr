{% skip_file unless flag?(:linux) %}

require "spec"
require "syscall"

describe Syscall do
  it "can call into the system successfuly" do
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
