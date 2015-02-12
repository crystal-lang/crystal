require "spec"
require "crypto/md5"

describe "MD5" do
  it "calculates hash from string" do
    Crypto::MD5.hex_digest("foo").should eq("acbd18db4cc2f85cedef654fccc4a4d8")
  end
end