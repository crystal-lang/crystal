require "spec"
require "system/group"

{% if flag?(:darwin) %}
  COMMON_GROUP = "wheel"
{% else %}
  COMMON_GROUP = "root"
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
end
