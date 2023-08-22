{% skip_file if flag?(:win32) %}

require "spec"
require "system/group"

GROUP_NAME         = {{ `id -gn`.stringify.chomp }}
GROUP_ID           = {{ `id -g`.stringify.chomp }}
INVALID_GROUP_NAME = "this_group_does_not_exist"
INVALID_GROUP_ID   = {% if flag?(:android) %}"8888"{% else %}"1234567"{% end %}

describe System::Group do
  describe ".find_by(*, name)" do
    it "returns a group by name" do
      group = System::Group.find_by(name: GROUP_NAME)

      group.should be_a(System::Group)
      group.name.should eq(GROUP_NAME)
      group.id.should eq(GROUP_ID)
    end

    it "raises on nonexistent group" do
      expect_raises System::Group::NotFoundError, "No such group" do
        System::Group.find_by(name: INVALID_GROUP_NAME)
      end
    end
  end

  describe ".find_by(*, id)" do
    it "returns a group by id" do
      group = System::Group.find_by(id: GROUP_ID)

      group.should be_a(System::Group)
      group.id.should eq(GROUP_ID)
      group.name.should eq(GROUP_NAME)
    end

    it "raises on nonexistent group name" do
      expect_raises System::Group::NotFoundError, "No such group" do
        System::Group.find_by(id: INVALID_GROUP_ID)
      end
    end
  end

  describe ".find_by?(*, name)" do
    it "returns a group by name" do
      group = System::Group.find_by?(name: GROUP_NAME).not_nil!

      group.should be_a(System::Group)
      group.name.should eq(GROUP_NAME)
      group.id.should eq(GROUP_ID)
    end

    it "returns nil on nonexistent group" do
      group = System::Group.find_by?(name: INVALID_GROUP_NAME)
      group.should eq(nil)
    end
  end

  describe ".find_by?(*, id)" do
    it "returns a group by id" do
      group = System::Group.find_by?(id: GROUP_ID).not_nil!

      group.should be_a(System::Group)
      group.id.should eq(GROUP_ID)
      group.name.should eq(GROUP_NAME)
    end

    it "returns nil on nonexistent group id" do
      group = System::Group.find_by?(id: INVALID_GROUP_ID)
      group.should eq(nil)
    end
  end

  describe "#name" do
    it "is the same as the source name" do
      System::Group.find_by(name: GROUP_NAME).name.should eq(GROUP_NAME)
    end
  end

  describe "#id" do
    it "is the same as the source ID" do
      System::Group.find_by(id: GROUP_ID).id.should eq(GROUP_ID)
    end
  end

  describe "#to_s" do
    it "returns a string representation" do
      System::Group.find_by(name: GROUP_NAME).to_s.should eq("#{GROUP_NAME} (#{GROUP_ID})")
    end
  end
end
