require "spec"
require "crypto/md5"

describe "Crypto" do
  it "calculates MD5 hash from string" do
    Crypto::MD5.hex_digest("foo").should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end
end
