require "spec"

describe AutoflushBufferedIO do
  it "flushes on \n" do
    str = StringIO.new
    io = AutoflushBufferedIO.new(str)
    io << "hello\nworld"
    str.to_s.should eq("hello\n")
    io.flush
    str.to_s.should eq("hello\nworld")
  end

  it "doesn't write past count" do
    str = StringIO.new
    io = AutoflushBufferedIO.new(str)
    slice = Slice.new(10) { |i| i == 9 ? '\n'.ord.to_u8 : ('a'.ord + i).to_u8 }
    io.write slice, 4
    io.flush
    str.to_s.should eq("abcd")
  end
end
