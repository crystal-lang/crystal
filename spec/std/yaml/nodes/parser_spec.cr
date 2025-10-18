require "yaml"
require "spec"

describe YAML::Nodes do
  describe ".parse" do
    it "attaches location to scalar nodes" do
      doc = YAML::Nodes.parse %(1)
      node = doc.nodes[0]
      node.location.should eq({1, 1})
      node.end_line.should eq(1)
      node.end_column.should eq(2)
    end

    it "attaches location to sequence nodes" do
      doc = YAML::Nodes.parse %([1])
      node = doc.nodes[0]
      node.location.should eq({1, 1})
      node.end_line.should eq(1)
      node.end_column.should eq(4)
    end

    it "attaches location to mapping nodes" do
      doc = YAML::Nodes.parse %({"a":1})
      node = doc.nodes[0]
      node.location.should eq({1, 1})
      node.end_line.should eq(1)
      node.end_column.should eq(8)
    end

    it "attaches location to alias nodes" do
      doc = YAML::Nodes.parse %([&a 1, *a])
      node = doc.nodes[0].as(YAML::Nodes::Sequence).nodes[1]
      node.location.should eq({1, 8})
      node.end_line.should eq(1)
      node.end_column.should eq(10)
    end
  end
end
