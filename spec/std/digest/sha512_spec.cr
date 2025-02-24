require "../spec_helper"
require "./spec_helper"
require "digest/sha512"

describe Digest::SHA512 do
  it_acts_as_digest_algorithm Digest::SHA512

  [
    {"", "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e", "z4PhNX7vuL3xVChQ1m2AB9Yg5AULVxXcg/SpIdNs6c5H0NE8XYXysP+DGNKHfuwvY7kxvUdBeoGlODJ6+SfaPg=="},
    {"The quick brown fox jumps over the lazy dog", "07e547d9586f6a73f73fbac0435ed76951218fb7d0c8d788a309d785436bbb642e93a252a954f23912547d1e8a3b5ed6e1bfd7097821233fa0538f3db854fee6", "B+VH2VhvanP3P7rAQ17XaVEhj7fQyNeIownXhUNru2Quk6JSqVTyORJUfR6KO17W4b/XCXghIz+gU489uFT+5g=="},
    {"abc", "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f", "3a81oZNherrMQXNJriBBMRLm+k6JqX6iCp7u5ktV05ohkpkqJ0/BqDa6PCOj/uu9RU1EI2Q86A4qmslPpUyknw=="},
    {"abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "204a8fc6dda82f0a0ced7beb8e08a41657c16ef468b228a8279be331a703c33596fd15c13b1b07f9aa1d3bea57789ca031ad85c7a71dd70354ec631238ca3445", "IEqPxt2oLwoM7XvrjgikFlfBbvRosiioJ5vjMacDwzWW/RXBOxsH+aodO+pXeJygMa2Fx6cd1wNU7GMSOMo0RQ=="},
    {"a", "1f40fc92da241694750979ee6cf582f2d5d7d28e18335de05abc54d0560e0f5302860c652bf08d560252aa5e74210546f369fbbbce8c12cfc7957b2652fe9a75", "H0D8ktokFpR1CXnubPWC8tXX0o4YM13gWrxU0FYOD1MChgxlK/CNVgJSql50IQVG82n7u86MEs/HlXsmUv6adQ=="},
    {"0123456701234567012345670123456701234567012345670123456701234567", "846e0ef73436438a4acb0ba7078cfe381f10a0f5edebcb985b3790086ef5e7ac5992ac9c23c77761c764bb3b1c25702d06b99955eb197d45b82fb3d124699d78", "hG4O9zQ2Q4pKywunB4z+OB8QoPXt68uYWzeQCG7156xZkqycI8d3YcdkuzscJXAtBrmZVesZfUW4L7PRJGmdeA=="},
    {"fooø", "082907b85fe25c33bba4765185b52993a493cfd24454edf4b977ccd9301a890659c52592456cbd8aeb5215055d9dd4a7d50a4db9961715fb764fb6c393a83192", "CCkHuF/iXDO7pHZRhbUpk6STz9JEVO30uXfM2TAaiQZZxSWSRWy9iutSFQVdndSn1QpNuZYXFft2T7bDk6gxkg=="},
  ].each do |(string, hexstring, base64digest)|
    it "does digest for #{string.inspect}" do
      bytes = Digest::SHA512.digest(string)
      bytes.hexstring.should eq(hexstring)
    end

    it "resets" do
      digest = Digest::SHA512.new
      digest.update string
      digest.final.hexstring.should eq(hexstring)

      digest.reset
      digest.update string
      digest.final.hexstring.should eq(hexstring)
    end

    it "can't call #final more than once" do
      digest = Digest::SHA512.new
      digest.final
      expect_raises(Digest::FinalizedError) do
        digest.final
      end
    end

    it "does digest for #{string.inspect} in a block" do
      bytes = Digest::SHA512.digest do |ctx|
        string.each_char do |chr|
          ctx.update chr.to_s
        end
      end

      bytes.hexstring.should eq(hexstring)
    end

    it "does .hexdigest for #{string.inspect}" do
      Digest::SHA512.hexdigest(string).should eq(hexstring)
    end

    it "does #hexdigest for #{string.inspect}" do
      digest = Digest::SHA512.new
      hdst = Bytes.new digest.digest_size * 2
      digest.update string

      digest.dup.hexfinal.should eq(hexstring)

      digest.hexfinal(hdst)
      String.new(hdst).should eq(hexstring)

      expect_raises(Digest::FinalizedError) do
        digest.final
      end
    end

    it "does base64digest for #{string.inspect}" do
      Digest::SHA512.base64digest(string).should eq(base64digest)
    end
  end

  it "returns the digest_size" do
    Digest::SHA512.new.digest_size.should eq(64)
  end
end
