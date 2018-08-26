{% skip_file if flag?(:win32) %}

require "spec"
require "system/group"
require "system/user"

private GROUP_NAME = "daemon"
private GROUP_ID   = "1"

{% if flag?(:darwin) %}
  private GROUP_USERS = `dscl . -read /Groups/#{GROUP_NAME} GroupMembership`.strip.split(':').last.split(' ', remove_empty: true)
{% else %}
  private GROUP_USERS = `getent group #{GROUP_NAME}`.strip.split(':').last.split(',', remove_empty: true)
{% end %}

private BAD_GROUP_NAME = "non_existent_group"
private BAD_GROUP_ID   = "123456"

describe System::Group do
  it "groupname from gid" do
    System::Group.name(GROUP_ID).should eq(GROUP_NAME)
    System::Group.name?(GROUP_ID).should eq(GROUP_NAME)

    expect_raises System::Group::NotFoundError do
      System::Group.name(BAD_GROUP_ID)
    end
    System::Group.name?(BAD_GROUP_ID).should be_nil
  end

  it "gid from groupname" do
    System::Group.gid(GROUP_NAME).should eq(GROUP_ID)
    System::Group.gid?(GROUP_NAME).should eq(GROUP_ID)

    expect_raises System::Group::NotFoundError do
      System::Group.gid(BAD_GROUP_NAME)
    end
    System::Group.gid?(BAD_GROUP_NAME).should be_nil
  end

  it "gets a group" do
    System::Group.get(GROUP_NAME).should_not be_nil
    System::Group.get(GROUP_ID).should_not be_nil

    System::Group.get?(GROUP_NAME).should_not be_nil
    System::Group.get?(GROUP_ID).should_not be_nil
  end

  it "gets a group from gid" do
    System::Group.from_gid(GROUP_ID)
    System::Group.from_gid?(GROUP_ID).should_not be_nil

    expect_raises System::Group::NotFoundError do
      System::Group.from_gid(GROUP_NAME)
    end
    System::Group.from_gid?(GROUP_NAME).should be_nil
  end

  it "gets a group from groupname" do
    System::Group.from_groupname(GROUP_NAME)
    System::Group.from_groupname?(GROUP_NAME).should_not be_nil

    expect_raises System::Group::NotFoundError do
      System::Group.from_groupname(GROUP_ID)
    end
    System::Group.from_groupname?(GROUP_ID).should be_nil
  end

  it "raises on group not found" do
    expect_raises System::Group::NotFoundError do
      System::Group.get(BAD_GROUP_NAME)
    end
    expect_raises System::Group::NotFoundError do
      System::Group.get(BAD_GROUP_ID)
    end

    System::Group.get?(BAD_GROUP_NAME).should be_nil
    System::Group.get?(BAD_GROUP_ID).should be_nil
  end

  it "raises GID out of bounds" do
    System::Group.valid_gid?(Crystal::System::Group::GID_MAX).should be_true

    expect_raises System::Group::NotFoundError do
      System::Group.get(Crystal::System::Group::GID_MAX.to_u64 + 1)
    end
  end

  it "has the correct properties" do
    group = System::Group.get(GROUP_NAME)
    group.name.should eq(GROUP_NAME)
    group.gid.should eq(GROUP_ID)
    group.user_names.should eq(GROUP_USERS)
    group.users.should eq(GROUP_USERS.map { |n| System::User.get(n) })

    group = System::Group.get(GROUP_ID)
    group.name.should eq(GROUP_NAME)
    group.gid.should eq(GROUP_ID)
    group.user_names.should eq(GROUP_USERS)
    group.users.should eq(GROUP_USERS.map { |n| System::User.get(n) })
  end
end
