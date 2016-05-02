require "spec"
require "crypto/md5"

describe Crypto::MD5 do
  it "calculates hash from string" do
    Crypto::MD5.hex_digest("foo").should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end

  it "calculates hash from UInt8 slices" do
    s = Slice(UInt8).new(3)
    s[0] = 0x66_u8 # 'f'
    s[1] = 0x6f_u8 # 'o'
    s[2] = 0x6f_u8 # 'o'
    Crypto::MD5.hex_digest(s).should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end

  it "can take a block" do
    s = Slice(UInt8).new(2)
    s[0] = 0x6f_u8 # 'o'
    s[1] = 0x6f_u8 # 'o'

    Crypto::MD5.hex_digest do |ctx|
      ctx.update "f"
      ctx.update s
    end.should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end
end
