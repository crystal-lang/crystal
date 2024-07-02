require "spec"
require "compress/zlib"

module Compress::Zlib
  describe Zlib do
    it "write read should be inverse with random string" do
      expected = String.build do |io|
        1_000_000.times { rand(2000).to_i.to_s(io, 32) }
      end

      io = IO::Memory.new

      writer = Writer.new(io)
      writer.print expected
      writer.close

      io.rewind
      reader = Reader.new(io)
      reader.gets_to_end.should eq(expected)
    end

    it "write read should be inverse (utf-8)" do
      expected = "日本さん語日本さん語"

      io = IO::Memory.new

      writer = Writer.new(io)
      writer.print expected
      writer.close

      io.rewind
      reader = Reader.new(io)
      reader.gets_to_end.should eq(expected)
    end
  end
end
