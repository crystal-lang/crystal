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

    it "returns the ios with an error condition" do
      with_pipe do |read, write|
        Thread.new do
          IO.select(nil, nil, {write}).includes?(write).should be_true
        end
        write.close
      end
    end

    it "times out" do
      with_pipe do |read, write|
        IO.select({read}, nil, nil, 0.00001).should be_nil
      end
    end
  end
end
