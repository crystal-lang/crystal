require "spec"
require "secure_random"

describe SecureRandom do
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
end
