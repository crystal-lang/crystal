require "spec"
require "base64"
require "crypto/md5"

describe "Base64" do
  it "simple test" do
    eqs = {"" => "", "a" => "YQ==\n", "ab" => "YWI=\n", "abc" => "YWJj\n",
           "abcd" => "YWJjZA==\n", "abcde"  => "YWJjZGU=\n", "abcdef" => "YWJjZGVm\n",
           "abcdefg" => "YWJjZGVmZw==\n"}
    eqs.each do |a, b|
      it "encode #{a.inspect} to #{b.inspect}" do
        expect(Base64.encode64(a)).to eq(b)
      end
      it "decode from #{b.inspect} to #{a.inspect}" do
        expect(Base64.decode64(b)).to eq(a)
      end
    end
  end

  it "encodes byte slice" do
    slice = Slice(UInt8).new(5) { 1_u8 }
    expect(Base64.encode64(slice)).to eq("AQEBAQE=\n")
    expect(Base64.strict_encode64(slice)).to eq("AQEBAQE=")
  end

  it "encodes static array" do
    array :: StaticArray(UInt8, 5)
    (0...5).each { |i| array[i] = 1_u8 }
    expect(Base64.encode64(array)).to eq("AQEBAQE=\n")
    expect(Base64.strict_encode64(array)).to eq("AQEBAQE=")
  end

  describe "base" do
    eqs = {"Send reinforcements" => "U2VuZCByZWluZm9yY2VtZW50cw==\n",
           "Now is the time for all good coders\nto learn Crystal" => "Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4g\nQ3J5c3RhbA==\n",
           "This is line one\nThis is line two\nThis is line three\nAnd so on...\n" =>
             "VGhpcyBpcyBsaW5lIG9uZQpUaGlzIGlzIGxpbmUgdHdvClRoaXMgaXMgbGlu\nZSB0aHJlZQpBbmQgc28gb24uLi4K\n",
           "hahah⊙ⓧ⊙" => "aGFoYWjiipnik6fiipk=\n"}
    eqs.each do |a, b|
      it "encode #{a.inspect} to #{b.inspect}" do
        expect(Base64.encode64(a)).to eq(b)
      end
      it "decode from #{b.inspect} to #{a.inspect}" do
        expect(Base64.decode64(b)).to eq(a)
      end
    end

    it "decode from strict form" do
      expect(Base64.decode64("Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4gQ3J5c3RhbA==")).to eq(
       "Now is the time for all good coders\nto learn Crystal")
    end

    it "big message" do
      a = "a" * 100000
      b = Base64.encode64(a)
      expect(Crypto::MD5.hex_digest(Base64.decode64(b))).to eq(Crypto::MD5.hex_digest(a))
    end

    it "works for most characters" do
      a = String.build(65536 * 4) do |buf|
        65536.times { |i| buf << (i + 1).chr }
      end
      b = Base64.encode64(a)
      expect(Crypto::MD5.hex_digest(Base64.decode64(b))).to eq(Crypto::MD5.hex_digest(a))
    end
  end

  describe "scrict" do
    it "encode" do
      expect(Base64.strict_encode64("Now is the time for all good coders\nto learn Crystal")).to eq(
        "Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4gQ3J5c3RhbA==")
    end
    it "decode" do
      expect(Base64.strict_decode64("Tm93IGlzIHRoZSB0aW1lIGZvciBhbGwgZ29vZCBjb2RlcnMKdG8gbGVhcm4gQ3J5c3RhbA==")).to eq(
       "Now is the time for all good coders\nto learn Crystal")
    end
    it "with spec symbols" do
      s = String.build { |b| (160..179).each{|i| b << i.chr } }
      se = "wqDCocKiwqPCpMKlwqbCp8KowqnCqsKrwqzCrcKuwq/CsMKxwrLCsw=="
      expect(Base64.strict_encode64(s)).to eq(se)
      expect(Base64.strict_decode64(se)).to eq(s)
    end
  end

  describe "urlsafe" do
    it "work" do
      s = String.build { |b| (160..179).each{|i| b << i.chr } }
      se = "wqDCocKiwqPCpMKlwqbCp8KowqnCqsKrwqzCrcKuwq_CsMKxwrLCsw"
      expect(Base64.urlsafe_encode64(s)).to eq(se)
      expect(Base64.urlsafe_decode64(se)).to eq(s)
    end
  end

end

