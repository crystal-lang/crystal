require "spec"
require "crypto/md5"

describe Crypto::MD5 do
  it "calculates hash from string" do
    Crypto::MD5.hex_digest("foo").should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end

  it "calculates hash from UInt8 slices" do
    s = Bytes[0x66, 0x6f, 0x6f] # f,o,o
    Crypto::MD5.hex_digest(s).should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end

  it "can take a block" do
    Crypto::MD5.hex_digest do |ctx|
      ctx.update "f"
      ctx.update Bytes[0x6f, 0x6f]
    end.should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end
end
