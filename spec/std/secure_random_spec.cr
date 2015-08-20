require "spec"
require "secure_random"

describe SecureRandom do
  describe "base64" do
    it "gets base64 with default number of digits" do
      base64 = SecureRandom.base64
      base64.length.should eq(24)
      base64.should_not match(/\n/)
    end

    it "gets base64 with requested number of digits" do
      base64 = SecureRandom.base64(50)
      base64.length.should eq(68)
      base64.should_not match(/\n/)
    end
  end

  describe "urlsafe_base64" do
    it "gets urlsafe base64 with default number of digits" do
      base64 = SecureRandom.urlsafe_base64
      (base64.length <= 24).should be_true
      base64.should_not match(/[\n+\/=]/)
    end

    it "gets urlsafe base64 with requested number of digits" do
      base64 = SecureRandom.urlsafe_base64(50)
      (base64.length >= 24 && base64.length <= 68).should be_true
      base64.should_not match(/[\n+\/=]/)
    end

    it "keeps padding" do
      base64 = SecureRandom.urlsafe_base64(padding: true)
      base64[-2..-1].should eq("==")
    end
  end

  describe "hex" do
    it "gets hex with default number of digits" do
      hex = SecureRandom.hex
      hex.length.should eq(32)
      hex.each_char do |char|
        ('0' <= char <= '9' || 'a' <= char <= 'f').should be_true
      end
    end

    it "gets hex with requested number of digits" do
      hex = SecureRandom.hex(50)
      hex.length.should eq(100)
      hex.each_char do |char|
        ('0' <= char <= '9' || 'a' <= char <= 'f').should be_true
      end
    end
  end

  describe "random_bytes" do
    it "gets random bytes with default number of digits" do
      bytes = SecureRandom.random_bytes
      bytes.length.should eq(16)
    end

    it "gets random bytes with requested number of digits" do
      bytes = SecureRandom.random_bytes(50)
      bytes.length.should eq(50)
    end
  end

  describe "uuid" do
    it "gets uuid" do
      uuid = SecureRandom.uuid
      uuid.should match(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{4}[0-9a-f]{8}\Z/)
    end
  end
end
