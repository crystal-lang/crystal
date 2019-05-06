require "spec"
require "system/group"

GROUP_NAME = {{ `id -gn`.stringify.chomp }}
GROUP_ID   = {{ `id -g`.stringify.to_i }}.to_u32!

describe System::Group do
  describe "from_name?" do
    it "returns a group by name" do
      group = System::Group.from_name?(GROUP_NAME).not_nil!

      group.should be_a(System::Group)
      group.name.should eq(GROUP_NAME)
      group.id.should eq(GROUP_ID)
    end

    it "returns nil on nonexistent group" do
      group = System::Group.from_name?("this_group_does_not_exist")
      group.should eq(nil)
    end
  end

  describe "from_name" do
    it "returns a group by name" do
      group = System::Group.from_name(GROUP_NAME)

      group.should be_a(System::Group)
      group.name.should eq(GROUP_NAME)
      group.id.should eq(GROUP_ID)
    end

    it "raises on nonexistent group" do
      expect_raises System::Group::NotFoundError, "No such group" do
        System::Group.from_name("this_group_does_not_exist")
      end
    end
  end

  describe "from_id?" do
    it "returns a group by id" do
      group = System::Group.from_id?(GROUP_ID).not_nil!

      group.should be_a(System::Group)
      group.id.should eq(GROUP_ID)
      group.name.should eq(GROUP_NAME)
    end

    it "returns nil on nonexistent group" do
      group = System::Group.from_id?(1234567_u32)
      group.should eq(nil)
    end
  end

  describe "from_id" do
    it "returns a group by id" do
      group = System::Group.from_id(GROUP_ID)

      group.should be_a(System::Group)
      group.id.should eq(GROUP_ID)
      group.name.should eq(GROUP_NAME)
    end

    it "raises on nonexistent group" do
      expect_raises System::Group::NotFoundError, "No such group" do
        System::Group.from_id(1234567_u32)
      end
    end
  end

  describe "name" do
    it "is a String" do
      System::Group.from_name(GROUP_NAME).name.should be_a(String)
    end
  end

  describe "password" do
    it "is a String" do
      System::Group.from_name(GROUP_NAME).password.should be_a(String)
    end
  end

  describe "id" do
    it "is a UInt32" do
      System::Group.from_name(GROUP_NAME).id.should be_a(UInt32)
    end
  end

  describe "members" do
    it "is an Array(String)" do
      System::Group.from_name(GROUP_NAME).members.should be_a(Array(String))
    end
  end
end
