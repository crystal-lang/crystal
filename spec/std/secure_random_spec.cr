require "spec"
require "secure_random"

describe SecureRandom do
  describe "hex" do
    it "gets hex with default number of digits" do
      hex = SecureRandom.hex
      expect(hex.length).to eq(32)
      hex.each_char do |char|
        expect(('0' <= char <= '9' || 'a' <= char <= 'f')).to be_true
      end
    end

    it "gets hex with requested number of digits" do
      hex = SecureRandom.hex(50)
      expect(hex.length).to eq(100)
      hex.each_char do |char|
        expect(('0' <= char <= '9' || 'a' <= char <= 'f')).to be_true
      end
    end
  end

  describe "random_bytes" do
    it "gets random bytes with default number of digits" do
      bytes = SecureRandom.random_bytes
      expect(bytes.length).to eq(16)
    end

    it "gets random bytes with requested number of digits" do
      bytes = SecureRandom.random_bytes(50)
      expect(bytes.length).to eq(50)
    end
  end
end
