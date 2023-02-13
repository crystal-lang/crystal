require "../spec_helper"
require "./spec_helper"
require "digest/crc32"

describe Digest::CRC32 do
  it_acts_as_digest_algorithm Digest::CRC32

  it "calculates digest from string" do
    Digest::CRC32.digest("foo").to_slice.should eq Bytes[0x8c, 0x73, 0x65, 0x21]
  end

  it "calculates hash from string" do
    Digest::CRC32.hexdigest("foo").should eq("8c736521")
  end

  it "calculates hash from unicode string" do
    Digest::CRC32.hexdigest("fooø").should eq("d5f3a18b")
  end

  it "calculates hash from UInt8 slices" do
    s = Bytes[0x66, 0x6f, 0x6f] # f,o,o
    Digest::CRC32.hexdigest(s).should eq("8c736521")
  end

  it "calculates hash of #to_slice" do
    buffer = StaticArray(UInt8, 1).new(1_u8)
    Digest::CRC32.hexdigest(buffer).should eq("a505df1b")
  end

  it "can take a block" do
    Digest::CRC32.hexdigest do |ctx|
      ctx.update "f"
      ctx.update Bytes[0x6f, 0x6f]
    end.should eq("8c736521")
  end

  it "calculates base64'd hash from string" do
    Digest::CRC32.base64digest("foo").should eq("jHNlIQ==")
  end

  it "resets" do
    digest = Digest::CRC32.new
    digest.update "foo"
    digest.final.hexstring.should eq("8c736521")

    digest.reset
    digest.update "foo"
    digest.final.hexstring.should eq("8c736521")
  end

  it "can't call final twice" do
    digest = Digest::CRC32.new
    digest.final
    expect_raises(Digest::FinalizedError) do
      digest.final
    end
  end

  it "return the digest size" do
    Digest::CRC32.new.digest_size.should eq 4
  end

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
