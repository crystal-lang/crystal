require "spec"
require "base64"
require "digest/md5"

describe "Base64" do
  context "simple test" do
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

  context "\n in multiple places" do
    eqs = {"abcd" => "YWJj\nZA==\n", "abcde" => "YWJj\nZGU=\n", "abcdef" => "YWJj\nZGVm\n",
           "abcdefg" => "YWJj\nZGVmZw==\n", "abcdefg" => "YWJj\nZGVm\nZw==\n",
    }
    eqs.each do |a, b|
      it "decode from #{b.inspect} to #{a.inspect}" do
        Base64.decode(b).should eq(a.to_slice)
        Base64.decode_string(b).should eq(a)
      end
    end
  end

  it "encodes byte slice" do
    slice = Bytes.new(5) { 1_u8 }
    Base64.encode(slice).should eq("AQEBAQE=\n")
    Base64.strict_encode(slice).should eq("AQEBAQE=")
  end

  it "encodes static array" do
    array = uninitialized StaticArray(UInt8, 5)
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

    it "encode to stream" do
      io = IO::Memory.new
      count = Base64.encode("Now is the time for all good coders\nto learn Crystal", io)
      count.should eq 74
      io.rewind
      io.gets_to_end.should eq "Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4g\nQ3J5c3RhbA==\n"
    end

    it "decode from stream" do
      io = IO::Memory.new
      count = Base64.decode("Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4gQ3J5c3RhbA==", io)
      count.should eq 52
      io.rewind
      io.gets_to_end.should eq "Now is the time for all good coders\nto learn Crystal"
    end

    it "big message" do
      a = "a" * 100000
      b = Base64.encode(a)
      Digest::MD5.hexdigest(Base64.decode_string(b)).should eq(Digest::MD5.hexdigest(a))
    end

    it "works for most characters" do
      a = String.build(65536 * 4) do |buf|
        65536.times { |i| buf << (i + 1).chr }
      end
      b = Base64.encode(a)
      Digest::MD5.hexdigest(Base64.decode_string(b)).should eq(Digest::MD5.hexdigest(a))
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

    it "decode small tail after last \n, was a bug" do
      s = "Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4g\nnA==\n"
      Base64.decode(s).should eq Bytes[78, 111, 119, 32, 105, 115, 32, 116, 104, 101, 32, 116, 105, 109, 101, 32, 102, 111, 114, 32, 97, 108, 108, 32, 103, 111, 111, 100, 32, 99, 111, 100, 101, 114, 115, 10, 116, 111, 32, 108, 101, 97, 114, 110, 32, 156]
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

    it "encode to stream" do
      s = String.build { |b| (160..179).each { |i| b << i.chr } }
      se = "wqDCocKiwqPCpMKlwqbCp8KowqnCqsKrwqzCrcKuwq/CsMKxwrLCsw=="
      io = IO::Memory.new
      Base64.strict_encode(s, io).should eq(56)
      io.rewind
      io.gets_to_end.should eq se
    end
  end

  describe "urlsafe" do
    it "work" do
      s = String.build { |b| (160..179).each { |i| b << i.chr } }
      se = "wqDCocKiwqPCpMKlwqbCp8KowqnCqsKrwqzCrcKuwq_CsMKxwrLCsw=="
      Base64.urlsafe_encode(s).should eq(se)
    end

    it "encode to stream" do
      s = String.build { |b| (160..179).each { |i| b << i.chr } }
      se = "wqDCocKiwqPCpMKlwqbCp8KowqnCqsKrwqzCrcKuwq_CsMKxwrLCsw=="
      io = IO::Memory.new
      Base64.urlsafe_encode(s, io).should eq(56)
      io.rewind
      io.gets_to_end.should eq se
    end
  end
end
