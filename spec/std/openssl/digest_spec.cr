require "spec"
require "../spec_helper"
require "../../../src/openssl"

describe OpenSSL::Digest do
  [
    {"SHA1", "dcf4a1e3542b1a40a4ac2a3f7c92ffdb2d19812f"},
    {"SHA256", "df81eea14671ce970fb1052e9f5dd6dbda652ed37423ed3624120ec1534784a7"},
    {"SHA512", "082907b85fe25c33bba4765185b52993a493cfd24454edf4b977ccd9301a890659c52592456cbd8aeb5215055d9dd4a7d50a4db9961715fb764fb6c393a83192"},
  ].each do |algorithm, expected|
    it "should be able to calculate #{algorithm}" do
      digest = OpenSSL::Digest.new(algorithm)
      digest << "fooø"
      digest.hexfinal.should eq(expected)

      digest.reset
      digest << "fooø"
      digest.final.hexstring.should eq(expected)
    end
  end

  it "can't call #final more than once" do
    digest = OpenSSL::Digest.new("SHA1")
    digest.final
    expect_raises(Digest::FinalizedError) do
      digest.final
    end
  end

  it "raises a UnsupportedError if digest is unsupported" do
    expect_raises OpenSSL::Digest::UnsupportedError do
      OpenSSL::Digest.new("unsupported")
    end
  end

  it "returns the digest size" do
    OpenSSL::Digest.new("SHA1").digest_size.should eq 20
    OpenSSL::Digest.new("SHA256").digest_size.should eq 32
  end

  it "returns the block size" do
    OpenSSL::Digest.new("SHA1").block_size.should eq 64
    OpenSSL::Digest.new("SHA256").block_size.should eq 64
  end

  it "correctly reads from IO" do
    r, w = IO.pipe
    digest = OpenSSL::Digest.new("SHA256")

    w << "foo"
    w.close
    digest << r
    r.close

    digest.hexfinal.should eq("2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae")
  end

  describe ".dup" do
    it "preserves type" do
      OpenSSL::Digest.new("MD5").dup.class.should eq(OpenSSL::Digest)
    end

    it "preserves value" do
      digest1 = OpenSSL::Digest.new("MD5")
      digest1.update("a")
      digest2 = digest1.dup

      digest1.final.should eq(digest2.final)
    end

    it "leads to not sharing state" do
      digest1 = OpenSSL::Digest.new("MD5")
      digest1.update("a")

      digest2 = digest1.dup

      digest1.update("b")

      digest1.final.should_not eq(digest2.final)
    end

    it "leads to deterministic updates" do
      digest1 = OpenSSL::Digest.new("MD5")
      digest1.update("a")

      digest2 = digest1.dup

      digest1.update("b")
      digest2.update("b")

      digest1.final.should eq(digest2.final)
    end
  end

  it "digest with file content" do
    path = datapath("test_file.txt")
    OpenSSL::Digest.new("MD5").file(path).final.hexstring.should eq("a4f13879534d2b93a9a65a4b2d0dde9d")
  end
end
