require "../../spec_helper"

describe "Crystal::Dependencies" do
  it "is empty" do
    deps = Dependencies.new
    deps.length.should eq(0)
    deps.to_a.should eq([] of ASTNode)
  end

  it "pushes one" do
    deps = Dependencies.new
    node = NilLiteral.new
    deps.push node
    deps.length.should eq(1)
    deps.to_a.map(&.object_id).should eq([node.object_id])
  end

  it "pushes two" do
    deps = Dependencies.new
    node1 = NilLiteral.new
    node2 = NilLiteral.new
    deps.push node1
    deps.push node2
    deps.length.should eq(2)
    deps.to_a.map(&.object_id).should eq([node1.object_id, node2.object_id])
  end

  it "pushes three" do
    deps = Dependencies.new
    node1 = NilLiteral.new
    node2 = NilLiteral.new
    node3 = NilLiteral.new
    deps.push node1
    deps.push node2
    deps.push node3
    deps.length.should eq(3)
    deps.to_a.map(&.object_id).should eq([node1.object_id, node2.object_id, node3.object_id])
  end
end
