require "spec"
require "zlib"

module Zlib
  describe Zlib do
    it "inflate deflate should be inverse with random string" do
      expected = String.build do |io|
        1_000_000.times { rand(2000).to_i.to_s(32, io) }
      end
      actual = Inflate.new(Deflate.new(MemoryIO.new(expected))).gets_to_end
      expected.should eq(actual)
    end

    it "inflate deflate should be inverse (utf-8)" do
      expected = "日本さん語日本さん語"
      actual = Inflate.new(Deflate.new(MemoryIO.new(expected))).gets_to_end
      expected.should eq(actual)
    end
  end
end
