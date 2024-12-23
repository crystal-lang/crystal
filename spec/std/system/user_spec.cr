require "spec"
require "system/user"

{% if flag?(:win32) %}
  {% parts = `whoami /USER /FO TABLE /NH`.stringify.chomp.split(" ") %}
  USER_NAME = {{ parts[0..-2].join(" ") }}
  USER_ID   = {{ parts[-1] }}
{% else %}
  USER_NAME = {{ `id -un`.stringify.chomp }}
  USER_ID   = {{ `id -u`.stringify.chomp }}
{% end %}

INVALID_USER_NAME = "this_user_does_not_exist"
INVALID_USER_ID   = {% if flag?(:android) %}"8888"{% else %}"1234567"{% end %}

def normalized_username(username)
  # on Windows, domain names are case-insensitive, so we unify the letter case
  # from sources like `whoami`, `hostname`, or Win32 APIs
  {% if flag?(:win32) %}
    username.upcase
  {% else %}
    username
  {% end %}
end

describe System::User do
  describe ".find_by(*, name)" do
    it "returns a user by name" do
      user = System::User.find_by(name: USER_NAME)

      user.should be_a(System::User)
      normalized_username(user.username).should eq(normalized_username(USER_NAME))
      user.id.should eq(USER_ID)
    end

    it "raises on a nonexistent user" do
      expect_raises System::User::NotFoundError, "No such user" do
        System::User.find_by(name: INVALID_USER_NAME)
      end
    end
  end

  describe ".find_by(*, id)" do
    it "returns a user by id" do
      user = System::User.find_by(id: USER_ID)

      user.should be_a(System::User)
      user.id.should eq(USER_ID)
      normalized_username(user.username).should eq(normalized_username(USER_NAME))
    end

    it "raises on nonexistent user id" do
      expect_raises System::User::NotFoundError, "No such user" do
        System::User.find_by(id: INVALID_USER_ID)
      end
    end
  end

  describe ".find_by?(*, name)" do
    it "returns a user by name" do
      user = System::User.find_by?(name: USER_NAME).not_nil!

      user.should be_a(System::User)
      normalized_username(user.username).should eq(normalized_username(USER_NAME))
      user.id.should eq(USER_ID)
    end

    it "returns nil on nonexistent user" do
      user = System::User.find_by?(name: INVALID_USER_NAME)
      user.should eq(nil)
    end
  end

  describe ".find_by?(*, id)" do
    it "returns a user by id" do
      user = System::User.find_by?(id: USER_ID).not_nil!

      user.should be_a(System::User)
      user.id.should eq(USER_ID)
      normalized_username(user.username).should eq(normalized_username(USER_NAME))
    end

    it "returns nil on nonexistent user id" do
      user = System::User.find_by?(id: INVALID_USER_ID)
      user.should eq(nil)
    end
  end

  describe "#username" do
    it "is the same as the source name" do
      user = System::User.find_by(name: USER_NAME)
      normalized_username(user.username).should eq(normalized_username(USER_NAME))
    end
  end

  describe "#id" do
    it "is the same as the source ID" do
      System::User.find_by(id: USER_ID).id.should eq(USER_ID)
    end
  end

  describe "#group_id" do
    it "calls without raising" do
      System::User.find_by(name: USER_NAME).group_id
    end
  end

  describe "#name" do
    it "calls without raising" do
      System::User.find_by(name: USER_NAME).name
    end
  end

  describe "#home_directory" do
    it "calls without raising" do
      System::User.find_by(name: USER_NAME).home_directory
    end
  end

  describe "#shell" do
    it "calls without raising" do
      System::User.find_by(name: USER_NAME).shell
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      user = System::User.find_by(name: USER_NAME)
      user.to_s.should eq("#{user.username} (#{user.id})")
    end
  end
end
