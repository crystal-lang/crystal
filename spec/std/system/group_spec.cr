require "spec"
require "system/group"
require "system/user"

{% if flag?(:darwin) || flag?(:openbsd) || flag?(:freebsd) %}
  private NAME_STRING = "wheel"
  private NAME_ID = 0
  private PROP_MEMBERS = ["root"]
{% elsif flag?(:linux) %}
  private NAME_STRING = "root"
  private NAME_ID = 0
  private PROP_MEMBERS = [] of String
{% else %}
  private NAME_STRING = "root"
  private NAME_ID = 0
  private PROP_MEMBERS = [] of String
{% end %}

private BAD_NAME_STRING = "non_existant_group"
private BAD_NAME_ID     = 123456

describe System::Group do
  it "groupname from gid" do
    System::Group.name(NAME_ID).should eq(NAME_STRING)
  end

  it "gid from groupname" do
    System::Group.gid(NAME_STRING).should eq(NAME_ID)
  end

  it "group existence" do
    System::Group.exists?(NAME_STRING).should be_true
    System::Group.exists?(NAME_ID).should be_true

    System::Group.exists?(BAD_NAME_STRING).should_not be_true
    System::Group.exists?(BAD_NAME_ID).should_not be_true
  end

  it "gets a group" do
    System::Group.get(NAME_STRING).should_not be_nil
    System::Group.get(NAME_ID).should_not be_nil

    System::Group.get?(NAME_STRING).should_not be_nil
    System::Group.get?(NAME_ID).should_not be_nil
  end

  it "raises on group not found" do
    expect_raises System::Group::NotFoundError do
      System::Group.get(BAD_NAME_STRING)
    end
    expect_raises System::Group::NotFoundError do
      System::Group.get(BAD_NAME_ID)
    end

    System::Group.get?(BAD_NAME_STRING).should be_nil
    System::Group.get?(BAD_NAME_ID).should be_nil
  end

  it "raises GID out of bounds" do
    System::Group.check_gid_in_bounds(System::Group::Limits::GID_MAX)

    expect_raises System::Group::OutOfBoundsError do
      System::Group.get(System::Group::Limits::GID_MAX.to_u64 + 1)
    end
  end

  it "has the correct properties" do
    group = System::Group.get(NAME_STRING)
    group.name.should eq(NAME_STRING)
    group.gid.should eq(NAME_ID)
    group.member_names.should eq(PROP_MEMBERS)
    group.members.should eq(PROP_MEMBERS.map { |n| System::User.get(n) })

    group = System::Group.get(NAME_ID)
    group.name.should eq(NAME_STRING)
    group.gid.should eq(NAME_ID)
    group.member_names.should eq(PROP_MEMBERS)
    group.members.should eq(PROP_MEMBERS.map { |n| System::User.get(n) })
  end
end
