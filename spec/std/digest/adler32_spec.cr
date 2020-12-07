require "spec"
require "digest/adler32"

describe Digest::Adler32 do
  it "should be able to calculate adler32" do
    adler = Digest::Adler32.checksum("foo").to_s(16)
    adler.should eq("2820145")
  end

  it "should be able to calculate adler32 combined" do
    adler1 = Digest::Adler32.checksum("hello")
    adler2 = Digest::Adler32.checksum(" world!")
    combined = Digest::Adler32.combine(adler1, adler2, " world!".size)
    Digest::Adler32.checksum("hello world!").should eq(combined)
  end
end
