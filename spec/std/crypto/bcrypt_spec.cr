require "spec"
require "crypto/bcrypt"
require "random/secure"

describe "Crypto::Bcrypt" do
  latin1_pound_sign = String.new(Bytes.new(1, 0xa3_u8))
  utf8_pound_sign = String.new(Bytes.new(2) { |i| i == 0 ? 0xc2_u8 : 0xa3_u8 })
  bit8_unicode_pound_sign = "\u00A3"

  vectors = [
    {6, "a", "m0CrhHm10qJ3lXRY.5zDGO", "3rS2KdeeWLuGmsfGlMfOxih58VYVfxe"},
    {6, "abc", "If6bvum7DFjUnE9p2uDeDu", "0YHzrHM6tf.iqN8.yx.jNN1ILEf7h0i"},
    {6, "abcdefghijklmnopqrstuvwxyz", ".rCVZVOThsIa97pEDOxvGu", "RRgzG64bvtJ0938xuqzv18d3ZpQhstC"},
    {6, "~!@#$%^&*()      ~!@#$%^&*()PNBFRD", "fPIsBO8qRqkjj273rfaOI.", "HtSV9jLDpTbZn782DC6/t7qT67P6FfO"},
    {8, "~!@#$%^&*()      ~!@#$%^&*()PNBFRD", "Eq2r4G/76Wv39MzSX262hu", "zPz612MZiYHVUJe/OcOql2jo4.9UxTW"},
    {10, "~!@#$%^&*()      ~!@#$%^&*()PNBFRD", "LgfYWkbzEvQ4JakH7rOvHe", "0y8pHKF9OaFgwUZ2q7W2FFZmZzJYlfS"},
    {5, latin1_pound_sign, "CCCCCCCCCCCCCCCCCCCCC.", "BvtRGGx3p8o0C5C36uS442Qqnrwofrq"},
    {5, utf8_pound_sign, "CCCCCCCCCCCCCCCCCCCCC.", "CAzSxlf0FLW7g1A5q7W/ZCj1xsN6A.e"},
    {5, bit8_unicode_pound_sign, "CCCCCCCCCCCCCCCCCCCCC.", "CAzSxlf0FLW7g1A5q7W/ZCj1xsN6A.e"},
  ]

  it "computes digest vectors" do
    vectors.each_with_index do |vector, index|
      cost, password, salt, digest = vector
      bc = Crypto::Bcrypt.new(password, salt, cost)
      Crypto::Bcrypt::Base64.encode(bc.digest, 23).should eq(digest)
    end
  end

  it "validates salt size" do
    expect_raises(Crypto::Bcrypt::Error, /Invalid salt size/) do
      Crypto::Bcrypt.new("abcd", Random::Secure.hex(7))
    end

    expect_raises(Crypto::Bcrypt::Error, /Invalid salt size/) do
      Crypto::Bcrypt.new("abcd", Random::Secure.hex(9))
    end
  end

  it "validates cost" do
    salt = Random::Secure.hex(8)

    expect_raises(Crypto::Bcrypt::Error, /Invalid cost/) do
      Crypto::Bcrypt.new("abcd", salt, 3)
    end

    expect_raises(Crypto::Bcrypt::Error, /Invalid cost/) do
      Crypto::Bcrypt.new("abcd", salt, 32)
    end
  end

  it "validates password size" do
    salt = Random::Secure.random_bytes(16)

    expect_raises(Crypto::Bcrypt::Error, /Invalid password size/) do
      Crypto::Bcrypt.new("".to_slice, salt)
    end

    expect_raises(Crypto::Bcrypt::Error, /Invalid password size/) do
      Crypto::Bcrypt.new("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 invalid".to_slice, salt)
    end
  end

  # Read http://lwn.net/Articles/448699/
  it "doesn't have the sign expansion (high 8bit) security flaw" do
    salt = "OK.fbVrR/bpIqNJ5ianF.C"
    hash1 = Crypto::Bcrypt.new("ab#{latin1_pound_sign}", salt, 5)
    hash2 = Crypto::Bcrypt.new(latin1_pound_sign, salt, 5)
    hash2.should_not eq(hash1)
  end
end
