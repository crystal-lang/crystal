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
        expect(IO.select({read}).includes?(read)).to be_true
      end
    end

    it "returns the available writable ios" do
      with_pipe do |read, write|
        expect(IO.select(nil, {write}).includes?(write)).to be_true
      end
    end

    it "times out" do
      with_pipe do |read, write|
        expect(IO.select({read}, nil, nil, 0.00001)).to be_nil
      end
    end
  end
end
