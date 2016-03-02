require "spec"
require "../src/openssl"

describe OpenSSL::PKey::RSA do
  it "should be able to generate RSA key" do
    rsa = OpenSSL::PKey::RSA.generate(1024)
    rsa.public_key?.should be_true
    rsa.private_key?.should be_true
    rsa.to_pem.match(/PRIVATE KEY/).should_not be_nil
  end

  it "should be able to private encrypt and public decrypt data" do
    rsa = OpenSSL::PKey::RSA.generate(1024)
    encrypted = rsa.private_encrypt "my secret"
    decrypted = rsa.public_decrypt(encrypted)
    String.new(decrypted).should eq("my secret")
  end

  it "should be able to public encrypt and private decrypt data" do
    rsa = OpenSSL::PKey::RSA.generate(1024)
    encrypted = rsa.public_encrypt "my secret"
    decrypted = rsa.private_decrypt(encrypted)
    String.new(decrypted).should eq("my secret")
  end

  it "should be able to get public key from private" do
    rsa = OpenSSL::PKey::RSA.generate(1024)
    pub_key = rsa.public_key

    pub_key.private_key?.should be_false
    expect_raises(OpenSSL::PKey::RSA::RSAError) do
      pub_key.private_encrypt("my secret")
    end
  end

  it "should be able to load RSA from pem" do
    rsa = OpenSSL::PKey::RSA.generate(1024)
    pem = MemoryIO.new
    rsa.to_pem(pem)

    pem.rewind

    new_rsa = OpenSSL::PKey::RSA.new(pem)
    rsa.to_pem.should eq(new_rsa.to_pem)
  end

  it "should be able to sign and verify data" do
    rsa = OpenSSL::PKey::RSA.generate(1024)
    digest = OpenSSL::Digest.new("SHA256")
    data = "my data"

    signature = rsa.sign(digest, data)
    rsa.verify(digest, signature, data).should be_true
    rsa.verify(digest, signature[0, 10], data).should be_false
  end
end
