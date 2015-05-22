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
end
