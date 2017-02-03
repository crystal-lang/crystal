require "spec"
require "crc32"

describe CRC32 do
  it "should be able to calculate crc32" do
    crc = CRC32.checksum("foo").to_s(16)
    crc.should eq("8c736521")
  end

  it "should be able to calculate crc32 combined" do
    crc1 = CRC32.checksum("hello")
    crc2 = CRC32.checksum(" world!")
    combined = CRC32.combine(crc1, crc2, " world!".size)
    CRC32.checksum("hello world!").should eq(combined)
  end
end
