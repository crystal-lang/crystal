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

  {% if compare_versions(LibSSL::OPENSSL_VERSION, "1.0.0") >= 0 || LibSSL::LIBRESSL_VERSION != "0.0.0" %}
    {% if compare_versions(LibSSL::OPENSSL_VERSION, "3.0.0") < 0 %}
      [
        {OpenSSL::Algorithm::MD4, 1, 16, "1857f69412150bca4542581d0f9e7fd1"},
        {OpenSSL::Algorithm::MD4, 1, 32, "1857f69412150bca4542581d0f9e7fd19332ff5c0b820cb0172457a29c5519be"},
        {OpenSSL::Algorithm::MD4, 2**16, 16, "3d87c982c8c4223f4af39406ac3882e6"},
        {OpenSSL::Algorithm::MD4, 2**16, 32, "3d87c982c8c4223f4af39406ac3882e6e6b92685dcf89f74df8caf7500b41883"},
        {OpenSSL::Algorithm::RIPEMD160, 1, 16, "b725258b125e0bacb0e2307e34feb16a"},
        {OpenSSL::Algorithm::RIPEMD160, 1, 32, "b725258b125e0bacb0e2307e34feb16a4d0d6aed6cb4b0eee458fc1829020428"},
        {OpenSSL::Algorithm::RIPEMD160, 2**16, 16, "93a8e007de2608e54911684cbebe2780"},
        {OpenSSL::Algorithm::RIPEMD160, 2**16, 32, "93a8e007de2608e54911684cbebe27808cc39fa59de9acdf74492155b46c4d2d"},
      ].each do |(algorithm, iterations, key_size, expected)|
        it "computes pbkdf2_hmac #{algorithm}" do
          OpenSSL::PKCS5.pbkdf2_hmac("password", "salt", iterations, algorithm, key_size).hexstring.should eq expected
        end
      end
    {% end %}

    [
      {OpenSSL::Algorithm::MD5, 1, 16, "f31afb6d931392daa5e3130f47f9a9b6"},
      {OpenSSL::Algorithm::MD5, 1, 32, "f31afb6d931392daa5e3130f47f9a9b6e8e72029d8350b9fb27a9e0e00b9d991"},
      {OpenSSL::Algorithm::MD5, 2**16, 16, "8b4ffd76e400c3b74b3d0fbfd9232048"},
      {OpenSSL::Algorithm::MD5, 2**16, 32, "8b4ffd76e400c3b74b3d0fbfd9232048762c86fe7684992c6f581f073f6625ee"},
      {OpenSSL::Algorithm::SHA1, 1, 16, "0c60c80f961f0e71f3a9b524af601206"},
      {OpenSSL::Algorithm::SHA1, 1, 32, "0c60c80f961f0e71f3a9b524af6012062fe037a6e0f0eb94fe8fc46bdc637164"},
      {OpenSSL::Algorithm::SHA1, 2**16, 16, "1b345dd55f62a35aecdb9229bc7ae95b"},
      {OpenSSL::Algorithm::SHA1, 2**16, 32, "1b345dd55f62a35aecdb9229bc7ae95b305a8d538940134627e46f82d3a41e5e"},
      {OpenSSL::Algorithm::SHA224, 1, 16, "3c198cbdb9464b7857966bd05b7bc92b"},
      {OpenSSL::Algorithm::SHA224, 1, 32, "3c198cbdb9464b7857966bd05b7bc92bc1cc4e6e63155d4e490557fd85989497"},
      {OpenSSL::Algorithm::SHA224, 2**16, 16, "53a7f042a8154092058cfe87e7fbf1c1"},
      {OpenSSL::Algorithm::SHA224, 2**16, 32, "53a7f042a8154092058cfe87e7fbf1c1f96826a9a2ffd8bcfda50bb9f60786f0"},
      {OpenSSL::Algorithm::SHA256, 1, 16, "120fb6cffcf8b32c43e7225256c4f837"},
      {OpenSSL::Algorithm::SHA256, 1, 32, "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b"},
      {OpenSSL::Algorithm::SHA256, 2**16, 16, "4156f668bb31db3a17f4d1b91424ef0d"},
      {OpenSSL::Algorithm::SHA256, 2**16, 32, "4156f668bb31db3a17f4d1b91424ef0d417ad1f35d055aceaebd8da0f6a44b7e"},
      {OpenSSL::Algorithm::SHA384, 1, 16, "c0e14f06e49e32d73f9f52ddf1d0c5c7"},
      {OpenSSL::Algorithm::SHA384, 1, 32, "c0e14f06e49e32d73f9f52ddf1d0c5c7191609233631dadd76a567db42b78676"},
      {OpenSSL::Algorithm::SHA384, 2**16, 16, "c7b5b0b726f6556587cced08d184253b"},
      {OpenSSL::Algorithm::SHA384, 2**16, 32, "c7b5b0b726f6556587cced08d184253bc9d2eb802db134fb9029b86ab25e7cd0"},
      {OpenSSL::Algorithm::SHA512, 1, 16, "867f70cf1ade02cff3752599a3a53dc4"},
      {OpenSSL::Algorithm::SHA512, 1, 32, "867f70cf1ade02cff3752599a3a53dc4af34c7a669815ae5d513554e1c8cf252"},
      {OpenSSL::Algorithm::SHA512, 2**16, 16, "6f64c3f8023813d8c2cab43cabfaa65e"},
      {OpenSSL::Algorithm::SHA512, 2**16, 32, "6f64c3f8023813d8c2cab43cabfaa65ed061822afe974060d8079d122fb869f4"},
    ].each do |(algorithm, iterations, key_size, expected)|
      it "computes pbkdf2_hmac #{algorithm}" do
        OpenSSL::PKCS5.pbkdf2_hmac("password", "salt", iterations, algorithm, key_size).hexstring.should eq expected
      end
    end
  {% end %}
end
