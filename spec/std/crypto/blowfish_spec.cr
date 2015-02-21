require "spec"
require "crypto/blowfish"

describe "Blowfish" do
  it "encrypt pair and decrypt pair" do
    bf = Crypto::Blowfish.new("Who is John Galt?")
    orig_l, orig_r = 0xfedcba98, 0x76543210

    l, r = bf.encrypt_pair(orig_l, orig_r)
    l.should eq(0xcc91732b)
    r.should eq(0x8022f684)

    l, r = bf.decrypt_pair(l, r)
    l.should eq(orig_l)
    r.should eq(orig_r)
  end

  it "raises if the key is empty" do
    expect_raises ArgumentError, /Invalid key size/ do
      Crypto::Blowfish.new("")
    end
  end

  it "raises if the key length is bigger than 56" do
    expect_raises ArgumentError, /Invalid key size/ do
      Crypto::Blowfish.new("a" * 57)
    end
  end

  it "folds the salt during the key schedule" do
    length = 32
    salt = String.build {|io| length.times {|i| io << (i + length).chr} }
    orig_l, orig_r = 0x00, 0x00
    
    bf = Blowfish.new
    bf.salted_expand_key("a" * length, salt)

    l, r = bf.encrypt_pair(orig_l, orig_r)
    l.should eq(0xc8f07bef)
    r.should eq(0x57deba64)
  end
end
