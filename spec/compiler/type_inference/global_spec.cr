require "../../spec_helper"

describe "Global inference" do
  it "infers type of global assign" do
    node = parse "$foo = 1"
    result = infer_type node
    mod, node = result.program, result.node as Assign

    node.type.should eq(mod.int32)
    node.target.type.should eq(mod.int32)
    node.value.type.should eq(mod.int32)
  end

  it "infers type of global assign with union" do
    nodes = parse "$foo = 1; $foo = 'a'"
    result = infer_type nodes
    mod, node = result.program, result.node as Expressions

    (node[0] as Assign).target.type.should eq(mod.union_of(mod.int32, mod.char))
    (node[1] as Assign).target.type.should eq(mod.union_of(mod.int32, mod.char))
  end

  it "infers type of global reference" do
    assert_type("$foo = 1; def foo; $foo = 'a'; end; foo; $foo") { union_of(int32, char) }
  end

  it "infers type of read global variable when not previously assigned" do
    assert_type("def foo; $foo; end; foo; $foo") { |mod| mod.nil }
  end

  it "infers type of write global variable when not previously assigned" do
    assert_type("def foo; $foo = 1; end; foo; $foo") { |mod| union_of(mod.nil, int32) }
  end
end
