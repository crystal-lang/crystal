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

  describe "==" do
    password = Crypto::Bcrypt::Password.create("secret", 4)

    it "verifies password is incorrect" do
      (password == "wrong").should be_false
    end

    it "verifies password is correct" do
      (password == "secret").should be_true
    end

    it "works with Password" do
      (password == password).should be_true

      other_password = Crypto::Bcrypt::Password.create("wrong", 4)
      (password == other_password).should be_false
    end

    it "works with other types" do
      (password == 0.815).should be_false
    end
  end
end
