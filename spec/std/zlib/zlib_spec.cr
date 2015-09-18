require "spec"
require "zlib"

describe Zlib do
  it "should be able to calculate adler32" do
    adler = Zlib.adler32("foo").to_s(16)
    adler.should eq("2820145")
  end

  it "should be able to calculate adler32 combined" do
    adler1 = Zlib.adler32("hello")
    adler2 = Zlib.adler32(" world!")
    combined = Zlib.adler32_combine(adler1, adler2, " world!".size)
    Zlib.adler32("hello world!").should eq(combined)
  end

  it "should be able to calculate crc32" do
    crc = Zlib.crc32("foo").to_s(16)
    crc.should eq("8c736521")
  end

  it "should be able to calculate crc32 combined" do
    crc1 = Zlib.crc32("hello")
    crc2 = Zlib.crc32(" world!")
    combined = Zlib.crc32_combine(crc1, crc2, " world!".size)
    Zlib.crc32("hello world!").should eq(combined)
  end
end
