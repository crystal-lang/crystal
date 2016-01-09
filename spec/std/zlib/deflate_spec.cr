require "spec"
require "zlib"

module Zlib
  describe Deflate do
    it "should be able to deflate" do
      io = MemoryIO.new
      deflate = Deflate.new(io)
      deflate.print "this is a test string !!!!\n"
      deflate.close

      io.to_slice.hexstring.should eq("789c2bc9c82c5600a2448592d4e21285e292a2ccbc74054520e00200854f087b")
    end

    it "can be closed" do
      io = MemoryIO.new
      deflate = Deflate.new(io)
      deflate.close
      deflate.closed?.should be_true
      io.closed?.should be_true

      expect_raises IO::Error, "closed stream" do
        deflate.print "a"
      end
    end

    it "can be flushed" do
      io = MemoryIO.new
      deflate = Deflate.new(io)

      deflate.print "this"
      io.to_slice.hexstring.should eq("789c")

      deflate.flush
      io.to_slice.hexstring.should eq("789c2ac9c82c06000000ffff")

      deflate.print " is a test string !!!!\n"
      deflate.close

      io.to_slice.hexstring.should eq("789c2ac9c82c06000000ffff53c82c56485428492d2e51282e29cacc4b575004022e00854f087b")
    end
  end
end
