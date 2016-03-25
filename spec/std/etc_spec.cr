require "spec"
require "etc"

describe "Etc" do
  describe "getlogin" do
    it "returns String or nil" do
      Etc.getlogin.should be_a(String | Nil)
    end
  end

  describe "getpwnam" do
    it "returns root user" do
      pwd = Etc.getpwnam("root")
      pwd.name.should eq("root")
      pwd.uid.should eq(0)
    end

    it "returns info for the current user" do
      if login = LibC.getlogin
        login = String.new(login)
        pwd = Etc.getpwnam(login)
        pwd.name.should eq(login)
      end
    end
  end

  describe "getpwuid" do
    it "returns root user" do
      pwd = Etc.getpwuid(0)
      pwd.name.should eq("root")
      pwd.uid.should eq(0)
    end
  end
end
