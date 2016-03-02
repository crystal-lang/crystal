require "spec"
require "../src/openssl"

describe OpenSSL::PKey::DSA do
  it "should be able to generate DSA key" do
    dsa = OpenSSL::PKey::DSA.generate(1024)
    dsa.public_key?.should be_true
    dsa.private_key?.should be_true
    dsa.to_pem.match(/PRIVATE KEY/).should_not be_nil
  end

  it "should be able to get public key from private" do
    dsa = OpenSSL::PKey::DSA.generate(1024)
    pub_key = dsa.public_key

    pub_key.private_key?.should be_false
  end

  it "should be able to load DSA from pem" do
    dsa = OpenSSL::PKey::DSA.generate(1024)
    pem = MemoryIO.new
    dsa.to_pem(pem)

    pem.rewind

    new_dsa = OpenSSL::PKey::DSA.new(pem)
    dsa.to_pem.should eq(new_dsa.to_pem)
  end

  it "should be able to sign and verify data" do
    dsa = OpenSSL::PKey::DSA.generate(1024)
    digest = OpenSSL::Digest.new("SHA256")
    data = "my data"

    signature = dsa.sign(digest, data)
    dsa.verify(digest, signature, data).should be_true
    expect_raises(OpenSSL::PKey::PKeyError) do
      dsa.verify(digest, signature[0, 10], data)
    end
  end

  it "should be able to dsa sign and verify" do
    dsa = OpenSSL::PKey::DSA.generate(1024)
    sha256 = OpenSSL::Digest.new("SHA256")
    data = "my data"
    digest = sha256.digest
    signature = dsa.dsa_sign(digest)

    dsa.dsa_verify(digest, signature).should be_true
  end
end
