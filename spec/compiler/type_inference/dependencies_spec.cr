require "../../spec_helper"

describe "Crystal::Dependencies" do
  it "is empty" do
    deps = Dependencies.new
    expect(deps.length).to eq(0)
    expect(deps.to_a).to eq([] of ASTNode)
  end

  it "pushes one" do
    deps = Dependencies.new
    node = NilLiteral.new
    deps.push node
    expect(deps.length).to eq(1)
    expect(deps.to_a.map(&.object_id)).to eq([node.object_id])
  end

  it "pushes two" do
    deps = Dependencies.new
    node1 = NilLiteral.new
    node2 = NilLiteral.new
    deps.push node1
    deps.push node2
    expect(deps.length).to eq(2)
    expect(deps.to_a.map(&.object_id)).to eq([node1.object_id, node2.object_id])
  end

  it "pushes three" do
    deps = Dependencies.new
    node1 = NilLiteral.new
    node2 = NilLiteral.new
    node3 = NilLiteral.new
    deps.push node1
    deps.push node2
    deps.push node3
    expect(deps.length).to eq(3)
    expect(deps.to_a.map(&.object_id)).to eq([node1.object_id, node2.object_id, node3.object_id])
  end
end
