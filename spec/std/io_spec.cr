require "spec"

private def with_pipe
  read, write = IO.pipe
  yield read, write
ensure
  read.close if read rescue nil
  write.close if write rescue nil
end

describe "IO" do
  describe ".select" do
    it "returns the available readable ios" do
      with_pipe do |read, write|
        write.puts "hey"
        write.close
        IO.select({read}).includes?(read).should be_true
      end
    end

    it "returns the available writable ios" do
      with_pipe do |read, write|
        IO.select(nil, {write}).includes?(write).should be_true
      end
    end

    it "times out" do
      with_pipe do |read, write|
        IO.select({read}, nil, nil, 0.00001).should be_nil
      end
    end
  end

  describe "IO iterators" do
    it "iterates by line" do
      io = StringIO.new("hello\nbye\n")
      lines = io.each_line
      lines.next.should eq("hello\n")
      lines.next.should eq("bye\n")
      lines.next.should be_a(Iterator::Stop)

      lines.rewind
      lines.next.should eq("hello\n")
    end

    it "iterates by char" do
      io = StringIO.new("abあぼ")
      chars = io.each_char
      chars.next.should eq('a')
      chars.next.should eq('b')
      chars.next.should eq('あ')
      chars.next.should eq('ぼ')
      chars.next.should be_a(Iterator::Stop)

      chars.rewind
      chars.next.should eq('a')
    end

    it "iterates by byte" do
      io = StringIO.new("ab")
      bytes = io.each_byte
      bytes.next.should eq('a'.ord)
      bytes.next.should eq('b'.ord)
      bytes.next.should be_a(Iterator::Stop)

      bytes.rewind
      bytes.next.should eq('a'.ord)
    end
  end

  it "copies" do
    string = "abあぼ"
    src = StringIO.new(string)
    dst = StringIO.new
    IO.copy(src, dst).should eq(string.bytesize)
    dst.to_s.should eq(string)
  end
end
