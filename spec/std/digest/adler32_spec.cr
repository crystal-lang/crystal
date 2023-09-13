require "../spec_helper"
require "./spec_helper"
require "digest/adler32"

describe Digest::Adler32 do
  it_acts_as_digest_algorithm Digest::Adler32

  it "calculates digest from string" do
    Digest::Adler32.digest("foo").to_slice.should eq Bytes[0x02, 0x82, 0x01, 0x45]
  end

  it "calculates hash from string" do
    Digest::Adler32.hexdigest("foo").should eq("02820145")
  end

  it "calculates hash from unicode string" do
    Digest::Adler32.hexdigest("fooø").should eq("074a02c0")
  end

  it "calculates hash from UInt8 slices" do
    s = Bytes[0x66, 0x6f, 0x6f] # f,o,o
    Digest::Adler32.hexdigest(s).should eq("02820145")
  end

  it "calculates hash of #to_slice" do
    buffer = StaticArray(UInt8, 1).new(1_u8)
    Digest::Adler32.hexdigest(buffer).should eq("00020002")
  end

  it "can take a block" do
    Digest::Adler32.hexdigest do |ctx|
      ctx.update "f"
      ctx.update Bytes[0x6f, 0x6f]
    end.should eq("02820145")
  end

  it "calculates base64'd hash from string" do
    Digest::Adler32.base64digest("foo").should eq("AoIBRQ==")
  end

  it "resets" do
    digest = Digest::Adler32.new
    digest.update "foo"
    digest.final.hexstring.should eq("02820145")

    digest.reset
    digest.update "foo"
    digest.final.hexstring.should eq("02820145")
  end

  it "can't call final twice" do
    digest = Digest::Adler32.new
    digest.final
    expect_raises(Digest::FinalizedError) do
      digest.final
    end
  end

  it "return the digest size" do
    Digest::Adler32.new.digest_size.should eq 4
  end

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
