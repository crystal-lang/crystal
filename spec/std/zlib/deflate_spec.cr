require "spec"
require "zlib"

module Zlib
  describe Deflate do
    it "should be able to deflate" do
      deflate = Deflate.new(MemoryIO.new("this is a test string !!!!\n"))
      slice = Slice(UInt8).new(32)
      read = deflate.read_fully(slice)

      slice[0, read.to_i32].hexstring.should eq("789c2bc9c82c5600a2448592d4e21285e292a2ccbc74054520e00200854f087b")
      deflate.read(slice).should eq(0)
    end
  end
end
