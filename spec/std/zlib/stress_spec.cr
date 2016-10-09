require "spec"
require "zlib"

module Zlib
  describe Zlib do
    it "inflate deflate should be inverse with random string" do
      expected = String.build do |io|
        1_000_000.times { rand(2000).to_i.to_s(32, io) }
      end

      io = IO::Memory.new

      deflate = Deflate.new(io)
      deflate.print expected
      deflate.close

      io.rewind
      inflate = Inflate.new(io)
      inflate.gets_to_end.should eq(expected)
    end

    it "inflate deflate should be inverse (utf-8)" do
      expected = "日本さん語日本さん語"

      io = IO::Memory.new

      deflate = Deflate.new(io)
      deflate.print expected
      deflate.close

      io.rewind
      inflate = Inflate.new(io)
      inflate.gets_to_end.should eq(expected)
    end
  end
end
