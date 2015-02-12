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
end
