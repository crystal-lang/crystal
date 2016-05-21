require "spec"
require "openssl/pkcs5"

describe OpenSSL::PKCS5 do
  it "computes pbkdf2_hmac_sha1" do
    [
      {1, 16, "0c60c80f961f0e71f3a9b524af601206"},
      {1, 32, "0c60c80f961f0e71f3a9b524af6012062fe037a6e0f0eb94fe8fc46bdc637164"},
      {2**16, 16, "1b345dd55f62a35aecdb9229bc7ae95b"},
      {2**16, 32, "1b345dd55f62a35aecdb9229bc7ae95b305a8d538940134627e46f82d3a41e5e"},
    ].each do |(iterations, key_size, expected)|
      OpenSSL::PKCS5.pbkdf2_hmac_sha1("password", "salt", iterations, key_size).hexstring.should eq expected
    end
  end
end
