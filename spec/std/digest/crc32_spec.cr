require "spec"
require "digest/crc32"

describe Digest::CRC32 do
  it "should be able to calculate crc32" do
    crc = Digest::CRC32.checksum("foo").to_s(16)
    crc.should eq("8c736521")
  end

  it "should be able to calculate crc32 combined" do
    crc1 = Digest::CRC32.checksum("hello")
    crc2 = Digest::CRC32.checksum(" world!")
    combined = Digest::CRC32.combine(crc1, crc2, " world!".size)
    Digest::CRC32.checksum("hello world!").should eq(combined)
  end
end
