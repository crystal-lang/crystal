require "spec"
require "system/user"

describe System::User do
  describe "from_name?" do
    it "returns a user by name" do
      user = System::User.from_name?("root").not_nil!

      user.should be_a(System::User)
      user.name.should eq("root")
    end

    it "returns nil on nonexistent user" do
      user = System::User.from_name?("this_user_does_not_exist")
      user.should eq(nil)
    end
  end

  describe "from_name" do
    it "returns a user by name" do
      user = System::User.from_name("root")

      user.should be_a(System::User)
      user.name.should eq("root")
    end

    it "raises on a nonexistent user" do
      expect_raises System::User::NotFound, "No such user" do
        System::User.from_name("this_user_does_not_exist")
      end
    end
  end

  describe "from_id?" do
    it "returns a user by id" do
      user = System::User.from_id?(0_u32).not_nil!

      user.should be_a(System::User)
      user.user_id.should eq(0_u32)
    end

    it "returns nil on nonexistent user" do
      user = System::User.from_id?(1234567_u32)
      user.should eq(nil)
    end
  end

  describe "from_id" do
    it "returns a user by id" do
      user = System::User.from_id(0_u32)

      user.should be_a(System::User)
      user.user_id.should eq(0_u32)
    end

    it "raises on nonexistent user" do
      expect_raises System::User::NotFound, "No such user" do
        System::User.from_id(1234567_u32)
      end
    end
  end

  describe "name" do
    it "is a String" do
      System::User.from_name("root").name.should be_a(String)
    end
  end

  describe "password" do
    it "is a String" do
      System::User.from_name("root").password.should be_a(String)
    end
  end

  describe "user_id" do
    it "is a UInt32" do
      System::User.from_name("root").user_id.should be_a(UInt32)
    end
  end

  describe "group_id" do
    it "is a UInt32" do
      System::User.from_name("root").group_id.should be_a(UInt32)
    end
  end

  describe "directory" do
    it "is a String" do
      System::User.from_name("root").directory.should be_a(String)
    end
  end

  describe "shell" do
    it "is a String" do
      System::User.from_name("root").shell.should be_a(String)
    end
  end
end
