require "../spec_helper"
require "./spec_helper"
require "digest/sha256"

describe Digest::SHA256 do
  it_acts_as_digest_algorithm Digest::SHA256

  [
    {"", "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="},
    {"The quick brown fox jumps over the lazy dog", "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592", "16j7swfXgJRpypq8sAguT41WUeRtPNt2LQLQvzfJ5ZI="},
    {"abc", "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0="},
    {"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", "JI1qYdIGOLjlwCaTDD5gOaM85Flk/yFn9uzt1BnbBsE="},
    {"a", "ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb", "ypeBEsobvcr6wjGzmiPcTaeG7/gUfE5yuYB3ha/uSLs="},
    {"0123456701234567012345670123456701234567012345670123456701234567", "8182cadb21af0e37c06414ece08e19c65bdb22c396d48ba7341012eea9ffdfdd", "gYLK2yGvDjfAZBTs4I4ZxlvbIsOW1IunNBAS7qn/390="},
    {"fooø", "df81eea14671ce970fb1052e9f5dd6dbda652ed37423ed3624120ec1534784a7", "34HuoUZxzpcPsQUun13W29plLtN0I+02JBIOwVNHhKc="},
  ].each do |(string, hexstring, base64digest)|
    it "does digest for #{string.inspect}" do
      bytes = Digest::SHA256.digest(string)
      bytes.hexstring.should eq(hexstring)
    end

    it "resets" do
      digest = Digest::SHA256.new
      digest.update string
      digest.final.hexstring.should eq(hexstring)

      digest.reset
      digest.update string
      digest.final.hexstring.should eq(hexstring)
    end

    it "can't call #final more than once" do
      digest = Digest::SHA256.new
      digest.final
      expect_raises(Digest::FinalizedError) do
        digest.final
      end
    end

    it "does digest for #{string.inspect} in a block" do
      bytes = Digest::SHA256.digest do |ctx|
        string.each_char do |chr|
          ctx.update chr.to_s
        end
      end

      bytes.hexstring.should eq(hexstring)
    end

    it "does hexdigest for #{string.inspect}" do
      Digest::SHA256.hexdigest(string).should eq(hexstring)
    end

    it "does base64digest for #{string.inspect}" do
      Digest::SHA256.base64digest(string).should eq(base64digest)
    end
  end

  it "returns the digest_size" do
    Digest::SHA256.new.digest_size.should eq(32)
  end
end
