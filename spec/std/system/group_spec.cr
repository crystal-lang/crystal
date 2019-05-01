require "spec"
require "system/group"

{% if flag?(:linux) %}
  COMMON_GROUP = "root"
{% else %}
  COMMON_GROUP = "wheel"
{% end %}

describe System::Group do
  describe "from_name?" do
    it "returns a group by name" do
      group = System::Group.from_name?(COMMON_GROUP).not_nil!

      group.should be_a(System::Group)
      group.name.should eq(COMMON_GROUP)
    end

    it "returns nil on nonexistent group" do
      group = System::Group.from_name?("this_group_does_not_exist")
      group.should eq(nil)
    end
  end

  describe "from_name" do
    it "returns a group by name" do
      group = System::Group.from_name(COMMON_GROUP)

      group.should be_a(System::Group)
      group.name.should eq(COMMON_GROUP)
    end

    it "raises on nonexistent group" do
      expect_raises System::Group::NotFound, "No such group" do
        System::Group.from_name("this_group_does_not_exist")
      end
    end
  end

  describe "from_id?" do
    it "returns a group by id" do
      group = System::Group.from_id?(0_u32).not_nil!

      group.should be_a(System::Group)
      group.id.should eq(0_u32)
    end

    it "returns nil on nonexistent group" do
      group = System::Group.from_id?(1234567_u32)
      group.should eq(nil)
    end
  end

  describe "from_id" do
    it "returns a group by id" do
      group = System::Group.from_id(0_u32)

      group.should be_a(System::Group)
      group.id.should eq(0_u32)
    end

    it "raises on nonexistent group" do
      expect_raises System::Group::NotFound, "No such group" do
        System::Group.from_id(1234567_u32)
      end
    end
  end

  describe "name" do
    it "is a String" do
      System::Group.from_name(COMMON_GROUP).name.should be_a(String)
    end
  end

  describe "password" do
    it "is a String" do
      System::Group.from_name(COMMON_GROUP).password.should be_a(String)
    end
  end

  describe "id" do
    it "is a UInt32" do
      System::Group.from_name(COMMON_GROUP).id.should be_a(UInt32)
    end
  end

  describe "members" do
    it "is an Array(String)" do
      System::Group.from_name(COMMON_GROUP).members.should be_a(Array(String))
    end
  end
end
