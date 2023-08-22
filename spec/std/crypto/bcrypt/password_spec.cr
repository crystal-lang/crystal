require "spec"
require "crypto/bcrypt/password"

describe "Crypto::Bcrypt::Password" do
  describe "new" do
    password = Crypto::Bcrypt::Password.new("$2a$08$K8y0i4Wyqyei3SiGHLEd.OweXJt7sno2HdPVrMvVf06kGgAZvPkga")

    it "parses version" do
      password.version.should eq("2a")
    end

    it "parses cost" do
      password.cost.should eq(8)
    end

    it "parses salt" do
      password.salt.should eq("K8y0i4Wyqyei3SiGHLEd.O")
    end

    it "parses digest" do
      password.digest.should eq("weXJt7sno2HdPVrMvVf06kGgAZvPkga")
    end

    it "validates the hash string has the required amount of parts" do
      expect_raises(Crypto::Bcrypt::Error, "Invalid hash string") do
        Crypto::Bcrypt::Password.new("blarp")
      end
    end

    it "raises on unsupported version (#11584)" do
      expect_raises(Crypto::Bcrypt::Error, "Invalid hash version") do
        Crypto::Bcrypt::Password.new("$-1$10$blarp")
      end
    end
  end

  describe "create" do
    password = Crypto::Bcrypt::Password.create("super secret", 5)

    it "uses cost" do
      password.cost.should eq(5)
    end

    it "generates salt" do
      password.salt.should_not be_nil
    end

    it "generates digest" do
      password.digest.should_not be_nil
    end
  end

  describe "verify" do
    password = Crypto::Bcrypt::Password.create("secret", 4)
    password2 = Crypto::Bcrypt::Password.new("$2$04$ZsHrsVlj.dsmn74Az1rjmeE/21nYRC0vB5LPjG7ySBfi6lRaO/P22")
    password2a = Crypto::Bcrypt::Password.new("$2a$04$ZsHrsVlj.dsmn74Az1rjmeE/21nYRC0vB5LPjG7ySBfi6lRaO/P22")
    password2b = Crypto::Bcrypt::Password.new("$2b$04$ZsHrsVlj.dsmn74Az1rjmeE/21nYRC0vB5LPjG7ySBfi6lRaO/P22")
    password2y = Crypto::Bcrypt::Password.new("$2y$04$ZsHrsVlj.dsmn74Az1rjmeE/21nYRC0vB5LPjG7ySBfi6lRaO/P22")

    it "verifies password is incorrect" do
      (password.verify "wrong").should be_false
    end

    it "verifies password is correct" do
      (password.verify "secret").should be_true
    end

    it "verifies password version 2 is correct (#11584)" do
      (password2.verify "secret").should be_true
    end
    it "verifies password version 2a is correct (#11584)" do
      (password2a.verify "secret").should be_true
    end
    it "verifies password version 2b is correct (#11584)" do
      (password2b.verify "secret").should be_true
    end
    it "verifies password version 2y is correct" do
      (password2y.verify "secret").should be_true
    end
  end
end
