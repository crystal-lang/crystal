require "spec"
require "crypto/bcrypt"

TEST_VECTORS = [
  # Partial list of ruby/java/bcrypt.NET/Python bcrypt test vectors.
  # Source: https://bitbucket.org/vadim/bcrypt.net
  { "",                                   "$2a$06$DCq7YPn5Rq63x1Lad4cll.",    "$2a$06$DCq7YPn5Rq63x1Lad4cll.TV4S6ytwfsfvkgY8jIucDrjc8deX1s." },
  { "a",                                  "$2a$06$m0CrhHm10qJ3lXRY.5zDGO",    "$2a$06$m0CrhHm10qJ3lXRY.5zDGO3rS2KdeeWLuGmsfGlMfOxih58VYVfxe" },
  { "abc",                                "$2a$06$If6bvum7DFjUnE9p2uDeDu",    "$2a$06$If6bvum7DFjUnE9p2uDeDu0YHzrHM6tf.iqN8.yx.jNN1ILEf7h0i" },
  { "abcdefghijklmnopqrstuvwxyz",         "$2a$06$.rCVZVOThsIa97pEDOxvGu",    "$2a$06$.rCVZVOThsIa97pEDOxvGuRRgzG64bvtJ0938xuqzv18d3ZpQhstC" },
  { "~!@#$%^&*()      ~!@#$%^&*()PNBFRD", "$2a$06$fPIsBO8qRqkjj273rfaOI.",    "$2a$06$fPIsBO8qRqkjj273rfaOI.HtSV9jLDpTbZn782DC6/t7qT67P6FfO" },
  { "~!@#$%^&*()      ~!@#$%^&*()PNBFRD", "$2a$08$Eq2r4G/76Wv39MzSX262hu",    "$2a$08$Eq2r4G/76Wv39MzSX262huzPz612MZiYHVUJe/OcOql2jo4.9UxTW" },
  { "~!@#$%^&*()      ~!@#$%^&*()PNBFRD", "$2a$10$LgfYWkbzEvQ4JakH7rOvHe",    "$2a$10$LgfYWkbzEvQ4JakH7rOvHe0y8pHKF9OaFgwUZ2q7W2FFZmZzJYlfS" },
  { "~!@#$%^&*()      ~!@#$%^&*()PNBFRD", "$2a$12$WApznUOJfkEGSmYRfnkrPO",    "$2a$12$WApznUOJfkEGSmYRfnkrPOr466oFDCaj4b6HY3EXGvfxm43seyhgC" },

  # latin-1 POUND SIGN
  { "\xa3", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.BvtRGGx3p8o0C5C36uS442Qqnrwofrq" },
  # utf-8 POUND SIGN
  { "\xc2\xa3", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.CAzSxlf0FLW7g1A5q7W/ZCj1xsN6A.e" }

  # add 8-bit unicode test as well; to verify PY3 encodes it as UTF-8.
  { "\u00A3", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.", "$2a$05$CCCCCCCCCCCCCCCCCCCCC.CAzSxlf0FLW7g1A5q7W/ZCj1xsN6A.e" },
]


describe "Bcrypt" do
  pending "tests against other implementations test vectors" do
    TEST_VECTORS.each do |vec|
      secret, salt, digest = vec
# BUG: test password generation with salt against test vectors
      Crypto::Bcrypt.verify(secret, digest).should be_true
    end
  end

  it "raises if cost is to low" do
    expect_raises ArgumentError, /Invalid cost size/ do
      Crypto::Bcrypt.digest("secret", 3)
    end
  end

  it "raises if cost is to high" do
    expect_raises ArgumentError, /Invalid cost size/ do
      Crypto::Bcrypt.digest("secret", 64)
    end
  end

  it "raises if hashedSecret is to short" do
    expect_raises ArgumentError, /Invalid hashedSecret size/ do
      Crypto::Bcrypt.verify("secret", "$2a$05$KxPkLhOwKE")
    end
  end

  it "raises if hash prefix is not $" do
    expect_raises ArgumentError, /Invalid hash prefix/ do
      Crypto::Bcrypt.verify("secret", "%2a$05$KxPkLhOwKEKzLkKuLBW0XOgTBBg7MxnhsvVqSWceIMDijE.scATDPN")
    end
  end

  it "raises if hash version is incorrect" do
    expect_raises ArgumentError, /Invalid hash version/ do
      Crypto::Bcrypt.verify("secret", "$3a$05$KxPkLhOwKEKzLkKuLBW0XOgTBBg7MxnhsvVqSWceIMDijE.scATDPN")
    end
  end

  it "raises if hash cost is incorrect" do
    expect_raises ArgumentError, /Invalid cost size/ do
      Crypto::Bcrypt.verify("secret", "$2a$03$KxPkLhOwKEKzLkKuLBW0XOgTBBg7MxnhsvVqSWceIMDijE.scATDPN")
    end
  end

  it "verifies whether the password is correct" do
    hash = Crypto::Bcrypt.digest("secret", 5)
    Crypto::Bcrypt.verify("secret", hash).should be_true
  end

  it "verifies whether the password is incorrect" do
    hash = Crypto::Bcrypt.digest("secret", 5)
    Crypto::Bcrypt.verify("Secret", hash).should be_false
  end
end
