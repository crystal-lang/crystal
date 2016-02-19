require "spec"
require "openssl"
require "openssl/hmac"

# Note: hacking the `DSS` test to use DSS1 because of an error when attempting
# to instantiate `OpenSSL::Digest::DSS.new`. Problem exists within Ruby's standard
# library as well.

describe OpenSSL::HMAC do
  [
    {:dss, "46b4ec586117154dacd49d664e5d63fdc88efb51"},
    {:dss1, "46b4ec586117154dacd49d664e5d63fdc88efb51"},
    {:md4, "f3593b56f00b25c8af31d02ddef6d2d0"},
    {:md5, "0c7a250281315ab863549f66cd8a3a53"},
    {:sha, "df3c18b162b0c3b1884ba1b8eaf60559c41abc50"},
    {:sha1, "46b4ec586117154dacd49d664e5d63fdc88efb51"},
    {:sha224, "4c1f774863acb63b7f6e9daa9b5c543fa0d5eccf61e3ffc3698eacdd"},
    {:sha256, "f9320baf0249169e73850cd6156ded0106e2bb6ad8cab01b7bbbebe6d1065317"},
    {:sha384, "3d10d391bee2364df2c55cf605759373e1b5a4ca9355d8f3fe42970471eca2e422a79271a0e857a69923839015877fc6"},
    {:sha512, "114682914c5d017dfe59fdc804118b56a3a652a0b8870759cf9e792ed7426b08197076bf7d01640b1b0684df79e4b67e37485669e8ce98dbab60445f0db94fce"},
    {:ripemd160, "20d23140503df606c91bda9293f1ad4a23afe509"},
  ].each do |tuple|
    it "computes #{tuple[0]}" do
      OpenSSL::HMAC.hexdigest(tuple[0], "foo", "bar").should eq(tuple[1])
    end

    it "computes #{tuple[0]} using an instance" do
      next if tuple[0] == :dss

      hmac = OpenSSL::HMAC.new tuple[0], "foo"
      hmac << "bar"
      hmac.hexdigest.should eq(tuple[1])
    end
  end
end
