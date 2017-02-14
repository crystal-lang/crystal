require "spec"
require "digest/sha1"

describe Digest::SHA1 do
  [
    {"", "da39a3ee5e6b4b0d3255bfef95601890afd80709", "2jmj7l5rSw0yVb/vlWAYkK/YBwk="},
    {"The quick brown fox jumps over the lazy dog", "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12", "L9ThxnotKPzthJ7hu3bnORuT6xI="},
    {"abc", "a9993e364706816aba3e25717850c26c9cd0d89d", "qZk+NkcGgWq6PiVxeFDCbJzQ2J0="},
    {"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "84983e441c3bd26ebaae4aa1f95129e5e54670f1", "hJg+RBw70m66rkqh+VEp5eVGcPE="},
    {"a", "86f7e437faa5a7fce15d1ddcb9eaeaea377667b8", "hvfkN/qlp/zhXR3cuerq6jd2Z7g="},
    {"0123456701234567012345670123456701234567012345670123456701234567", "e0c094e867ef46c350ef54a7f59dd60bed92ae83", "4MCU6GfvRsNQ71Sn9Z3WC+2SroM="},
  ].each do |(string, hexdigest, base64digest)|
    it "does digest for #{string.inspect}" do
      bytes = Digest::SHA1.digest(string)
      bytes.to_slice.hexstring.should eq(hexdigest)
    end

    it "does digest for #{string.inspect} in a block" do
      bytes = Digest::SHA1.digest do |ctx|
        string.each_char do |chr|
          ctx.update chr.to_s
        end
      end

      bytes.to_slice.hexstring.should eq(hexdigest)
    end

    it "does hexdigest for #{string.inspect}" do
      Digest::SHA1.hexdigest(string).should eq(hexdigest)
    end

    it "does base64digest for #{string.inspect}" do
      Digest::SHA1.base64digest(string).should eq(base64digest)
    end
  end
end
