require "spec"
require "system/user"

USER_NAME = {{ `id -un`.stringify.chomp }}
USER_ID   = {{ `id -u`.stringify.to_i }}.to_u32!

describe System::User do
  describe "from_name?" do
    it "returns a user by name" do
      user = System::User.from_name?(USER_NAME).not_nil!

      user.should be_a(System::User)
      user.name.should eq(USER_NAME)
      user.user_id.should eq(USER_ID)
    end

    it "returns nil on nonexistent user" do
      user = System::User.from_name?("this_user_does_not_exist")
      user.should eq(nil)
    end
  end

  describe "from_name" do
    it "returns a user by name" do
      user = System::User.from_name(USER_NAME)

      user.should be_a(System::User)
      user.name.should eq(USER_NAME)
      user.user_id.should eq(USER_ID)
    end

    it "raises on a nonexistent user" do
      expect_raises System::User::NotFoundError, "No such user" do
        System::User.from_name("this_user_does_not_exist")
      end
    end
  end

  describe "from_id?" do
    it "returns a user by id" do
      user = System::User.from_id?(USER_ID).not_nil!

      user.should be_a(System::User)
      user.user_id.should eq(USER_ID)
      user.name.should eq(USER_NAME)
    end

    it "returns nil on nonexistent user" do
      user = System::User.from_id?(1234567_u32)
      user.should eq(nil)
    end
  end

  describe "from_id" do
    it "returns a user by id" do
      user = System::User.from_id(USER_ID)

      user.should be_a(System::User)
      user.user_id.should eq(USER_ID)
      user.name.should eq(USER_NAME)
    end

    it "raises on nonexistent user" do
      expect_raises System::User::NotFoundError, "No such user" do
        System::User.from_id(1234567_u32)
      end
    end
  end

  describe "name" do
    it "is the same as the source name" do
      System::User.from_name(USER_NAME).name.should eq(USER_NAME)
    end
  end

  describe "user_id" do
    it "is the same as the source ID" do
      System::User.from_id(USER_ID).user_id.should eq(USER_ID)
    end
  end

  describe "group_id" do
    it "calls without raising" do
      System::User.from_name(USER_NAME).group_id
    end
  end

  describe "directory" do
    it "calls without raising" do
      System::User.from_name(USER_NAME).directory
    end
  end

  describe "shell" do
    it "calls without raising" do
      System::User.from_name(USER_NAME).shell
    end
  end
end
