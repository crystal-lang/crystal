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

  describe ".parse_all" do
    it "returns all documents" do
      docs = YAML::Nodes.parse_all <<-YAML
        ---
        1
        ---
        [2]
        YAML

      docs.size.should eq(2)
      docs[0].location.should eq({1, 1})
      docs[0].end_line.should eq(3)
      docs[0].end_column.should eq(1)
      docs[1].location.should eq({3, 1})
      docs[1].end_line.should eq(5)
      docs[1].end_column.should eq(1)

      node = docs[0].nodes[0].should be_a(YAML::Nodes::Scalar)
      node.value.should eq("1")
      node.location.should eq({2, 1})
      node.end_line.should eq(2)
      node.end_column.should eq(2)

      node = docs[1].nodes[0].should be_a(YAML::Nodes::Sequence)
      node.nodes[0].should(be_a(YAML::Nodes::Scalar)).value.should eq("2")
      node.location.should eq({4, 1})
      node.end_line.should eq(4)
      node.end_column.should eq(4)
    end
  end
end
