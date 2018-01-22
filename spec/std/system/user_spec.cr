require "spec"
require "system/user"

private NAME_STRING = "root"
private NAME_ID     = 0

private PROP_GID = 0
{% if flag?(:darwin) %}
  private PROP_HOME = "/var/root"
  private PROP_SHELL = "/bin/sh"
  private PROP_INFO = "System Administrator"
{% elsif flag?(:openbsd) %}
  private PROP_HOME = "/root"
  private PROP_SHELL = "/bin/ksh"
  private PROP_INFO = "Charlie &"
{% elsif flag?(:freebsd) %}
  private PROP_HOME = "/root"
  private PROP_SHELL = "/bin/csh"
  private PROP_INFO = "Charlie &"
{% elsif flag?(:linux) %}
  private PROP_HOME = "/root"
  private PROP_SHELL = "/bin/bash"
  private PROP_INFO = "root"
{% else %}
  private PROP_HOME = "/root"
  private PROP_SHELL = "/bin/bash"
  private PROP_INFO = "root"
{% end %}

private BAD_NAME_STRING = "non_existant_user"
private BAD_NAME_ID     = 1234567

describe System::User do
  it "username from uid" do
    System::User.name(NAME_ID).should eq(NAME_STRING)
  end

  it "uid from username" do
    System::User.uid(NAME_STRING).should eq(NAME_ID)
  end

  it "user existence" do
    System::User.exists?(NAME_STRING).should be_true
    System::User.exists?(NAME_ID).should be_true

    System::User.exists?(BAD_NAME_STRING).should_not be_true
    System::User.exists?(BAD_NAME_ID).should_not be_true
  end

  it "gets a user" do
    System::User.get(NAME_STRING)
    System::User.get(NAME_ID)

    System::User.get?(NAME_STRING).should_not be_nil
    System::User.get?(NAME_ID).should_not be_nil
  end

  it "raises on user not found" do
    expect_raises System::User::NotFoundError do
      System::User.get(BAD_NAME_STRING)
    end
    expect_raises System::User::NotFoundError do
      System::User.get(BAD_NAME_ID)
    end

    System::User.get?(BAD_NAME_STRING).should be_nil
    System::User.get?(BAD_NAME_ID).should be_nil
  end

  it "raises UID out of bounds" do
    System::User.check_uid_in_bounds(System::User::Limits::UID_MAX)

    expect_raises System::User::OutOfBoundsError do
      System::User.get(System::User::Limits::UID_MAX.to_u64 + 1)
    end
  end

  it "has the correct properties" do
    user = System::User.get(NAME_STRING)
    user.name.should eq(NAME_STRING)
    user.uid.should eq(NAME_ID)
    user.gid.should eq(PROP_GID)
    user.home.should eq(PROP_HOME)
    user.shell.should eq(PROP_SHELL)
    user.info.should eq(PROP_INFO)

    user = System::User.get(NAME_ID)
    user.name.should eq(NAME_STRING)
    user.uid.should eq(NAME_ID)
    user.gid.should eq(PROP_GID)
    user.home.should eq(PROP_HOME)
    user.shell.should eq(PROP_SHELL)
    user.info.should eq(PROP_INFO)
  end
end
