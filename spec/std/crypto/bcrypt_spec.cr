require "spec"
require "crypto/bcrypt"

describe "Bcrypt" do
  it "raises if cost is to low" do
    expect_raises ArgumentError, /Invalid cost size/ do
      Crypto::Bcrypt.digest("secret", 3)
    end
  end

  it "raises if cost is to high" do 
    expect_raises ArgumentError, /Invalid cost size/ do
      Crypto::Bcrypt.digest("secret", 32)
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

  it "verified whether the password is correct" do
    hash = Crypto::Bcrypt.digest("secret", 5)
    Crypto::Bcrypt.verify("secret", hash).should be_true
  end

  it "verified whether the password is incorrect" do
    hash = Crypto::Bcrypt.digest("secret", 5)
    Crypto::Bcrypt.verify("Secret", hash).should be_false
  end
end