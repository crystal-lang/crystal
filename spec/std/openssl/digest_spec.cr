require "spec"
require "../src/openssl"

describe OpenSSL::Digest do
  [
    {"SHA1", "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33"},
    {"SHA256", "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"},
    {"SHA512", "f7fbba6e0636f890e56fbbf3283e524c6fa3204ae298382d624741d0dc6638326e282c41be5e4254d8820772c5518a2c5a8c0c7f7eda19594a7eb539453e1ed7"},
  ].each do |tuple|
    it "should be able to calculate #{tuple[0]}" do
      digest = OpenSSL::Digest.new(tuple[0])
      digest << "foo"
      digest.hexdigest.should eq(tuple[1])
    end
  end

  it "raises a UnsupportedError if digest is unsupported" do
    expect_raises OpenSSL::Digest::UnsupportedError do
      OpenSSL::Digest.new("unsupported")
    end
  end
end
