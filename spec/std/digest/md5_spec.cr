require "../spec_helper"
require "./spec_helper"
require "digest/md5"

describe Digest::MD5 do
  it_acts_as_digest_algorithm Digest::MD5

  it "calculates digest from string" do
    Digest::MD5.digest("foo").to_slice.should eq Bytes[0xac, 0xbd, 0x18, 0xdb, 0x4c, 0xc2, 0xf8, 0x5c, 0xed, 0xef, 0x65, 0x4f, 0xcc, 0xc4, 0xa4, 0xd8]
  end

  it "calculates hash from string" do
    Digest::MD5.hexdigest("foo").should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end

  it "calculates hash from unicode string" do
    Digest::MD5.hexdigest("fooø").should eq("d841c4eb31535db11faab98d10316b29")
  end

  it "calculates hash from UInt8 slices" do
    s = Bytes[0x66, 0x6f, 0x6f] # f,o,o
    Digest::MD5.hexdigest(s).should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end

  it "calculates hash of #to_slice" do
    buffer = StaticArray(UInt8, 1).new(1_u8)
    Digest::MD5.hexdigest(buffer).should eq("55a54008ad1ba589aa210d2629c1df41")
  end

  it "can take a block" do
    Digest::MD5.hexdigest do |ctx|
      ctx.update "f"
      ctx.update Bytes[0x6f, 0x6f]
    end.should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end

  it "calculates base64'd hash from string" do
    Digest::MD5.base64digest("foo").should eq("rL0Y20zC+Fzt72VPzMSk2A==")
  end

  it "resets" do
    digest = Digest::MD5.new
    digest.update "foo"
    digest.hexfinal.should eq("acbd18db4cc2f85cedef654fccc4a4d8")

    digest.reset
    digest.update "foo"
    digest.hexfinal.should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end

  it "#hexfinal" do
    digest = Digest::MD5.new
    digest.update "foo"
    dst = Bytes.new digest.digest_size * 2
    digest.hexfinal(dst)
    String.new(dst).should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end

  it "can't call final twice" do
    digest = Digest::MD5.new
    digest.final
    expect_raises(Digest::FinalizedError) do
      digest.final
    end
    expect_raises(Digest::FinalizedError) do
      digest.hexfinal
    end
  end

  it "return the digest size" do
    Digest::MD5.new.digest_size.should eq 16
  end
end
