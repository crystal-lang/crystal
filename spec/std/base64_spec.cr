require "spec"
require "base64"
require "crypto/md5"

describe "Base64" do
  it "simple test" do
    eqs = {"" => "", "a" => "YQ==\n", "ab" => "YWI=\n", "abc" => "YWJj\n",
      "abcd" => "YWJjZA==\n", "abcde" => "YWJjZGU=\n", "abcdef" => "YWJjZGVm\n",
      "abcdefg" => "YWJjZGVmZw==\n"}
    eqs.each do |a, b|
      it "encode #{a.inspect} to #{b.inspect}" do
        Base64.encode(a).should eq(b)
      end
      it "decode from #{b.inspect} to #{a.inspect}" do
        Base64.decode(b).should eq(a.to_slice)
        Base64.decode_string(b).should eq(a)
      end
    end
  end

  it "encodes byte slice" do
    slice = Slice(UInt8).new(5) { 1_u8 }
    Base64.encode(slice).should eq("AQEBAQE=\n")
    Base64.strict_encode(slice).should eq("AQEBAQE=")
  end

  it "encodes static array" do
    array :: StaticArray(UInt8, 5)
    (0...5).each { |i| array[i] = 1_u8 }
    Base64.encode(array).should eq("AQEBAQE=\n")
    Base64.strict_encode(array).should eq("AQEBAQE=")
  end

  describe "base" do
    eqs = {"Send reinforcements"                                                    => "U2VuZCByZWluZm9yY2VtZW50cw==\n",
      "Now is the time for all good coders\nto learn Crystal"                  => "Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4g\nQ3J5c3RhbA==\n",
      "This is line one\nThis is line two\nThis is line three\nAnd so on...\n" => "VGhpcyBpcyBsaW5lIG9uZQpUaGlzIGlzIGxpbmUgdHdvClRoaXMgaXMgbGlu\nZSB0aHJlZQpBbmQgc28gb24uLi4K\n",
      "hahah⊙ⓧ⊙"                                                               => "aGFoYWjiipnik6fiipk=\n"}
    eqs.each do |a, b|
      it "encode #{a.inspect} to #{b.inspect}" do
        Base64.encode(a).should eq(b)
      end
      it "decode from #{b.inspect} to #{a.inspect}" do
        Base64.decode(b).should eq(a.to_slice)
        Base64.decode_string(b).should eq(a)
      end
    end

    it "decode from strict form" do
      Base64.decode_string("Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4gQ3J5c3RhbA==").should eq(
        "Now is the time for all good coders\nto learn Crystal")
    end

    it "big message" do
      a = "a" * 100000
      b = Base64.encode(a)
      Crypto::MD5.hex_digest(Base64.decode_string(b)).should eq(Crypto::MD5.hex_digest(a))
    end

    it "works for most characters" do
      a = String.build(65536 * 4) do |buf|
        65536.times { |i| buf << (i + 1).chr }
      end
      b = Base64.encode(a)
      Crypto::MD5.hex_digest(Base64.decode_string(b)).should eq(Crypto::MD5.hex_digest(a))
    end
  end

  describe "decode cases" do
    it "decode \r\n" do
      decoded = "hahah⊙ⓧ⊙"
      {"aGFo\r\nYWjiipnik6fiipk=\r\n", "aGFo\r\nYWjiipnik6fiipk=\r\n\r\n"}.each do |encoded|
        Base64.decode(encoded).should eq(decoded.to_slice)
        Base64.decode_string(encoded).should eq(decoded)
      end
    end

    it "decode \n in multiple places" do
      decoded = "hahah⊙ⓧ⊙"
      {"aGFoYWjiipnik6fiipk=", "aGFo\nYWjiipnik6fiipk=", "aGFo\nYWji\nipnik6fiipk=",
        "aGFo\nYWji\nipni\nk6fiipk=", "aGFo\nYWji\nipni\nk6fi\nipk=",
        "aGFo\nYWji\nipni\nk6fi\nipk=\n"}.each do |encoded|
        Base64.decode(encoded).should eq(decoded.to_slice)
        Base64.decode_string(encoded).should eq(decoded)
      end
    end

    it "raise error when \n in incorrect place" do
      expect_raises Base64::Error do
        Base64.decode("aG\nFoYWjiipnik6fiipk=")
      end

      expect_raises Base64::Error do
        Base64.decode_string("aG\nFoYWjiipnik6fiipk=")
      end
    end

    it "raise error when incorrect symbol" do
      expect_raises Base64::Error do
        Base64.decode("()")
      end

      expect_raises Base64::Error do
        Base64.decode_string("()")
      end
    end

    it "raise error when incorrect size" do
      expect_raises Base64::Error do
        Base64.decode("a")
      end

      expect_raises Base64::Error do
        Base64.decode_string("a")
      end
    end
  end

  describe "scrict" do
    it "encode" do
      Base64.strict_encode("Now is the time for all good coders\nto learn Crystal").should eq(
        "Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4gQ3J5c3RhbA==")
    end
    it "with spec symbols" do
      s = String.build { |b| (160..179).each { |i| b << i.chr } }
      se = "wqDCocKiwqPCpMKlwqbCp8KowqnCqsKrwqzCrcKuwq/CsMKxwrLCsw=="
      Base64.strict_encode(s).should eq(se)
    end
  end

  describe "urlsafe" do
    it "work" do
      s = String.build { |b| (160..179).each { |i| b << i.chr } }
      se = "wqDCocKiwqPCpMKlwqbCp8KowqnCqsKrwqzCrcKuwq_CsMKxwrLCsw"
      Base64.urlsafe_encode(s).should eq(se)
    end
  end
end
