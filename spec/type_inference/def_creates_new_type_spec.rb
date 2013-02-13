require 'spec_helper'

describe 'Type inference: def new type' do
  it "it not a new type if no allocate" do
    nodes = parse "def foo; 1; end; foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_false
  end

  it "it is a new type if allocate" do
    nodes = parse "generic class Foo; end; def foo; Foo.allocate; end; foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_true
  end

  it "it is a new type if allocate and assigned to var" do
    nodes = parse "generic class Foo; end; def foo; x = Foo.allocate; x; end; foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_true
  end

  it "it is a new type if allocate and assigned to var and assigned to something else" do
    nodes = parse "generic class Foo; end; def foo; x = Foo.allocate; if false; x = 1; end; x; end; foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_true
  end

  it "it is a new type if new and assigned to var" do
    nodes = parse "generic class Foo; end; def foo; x = Foo.new; x; end; foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_true
  end

  it "it is not a new type if static method no allocate" do
    nodes = parse "generic class Foo; end; def Foo.foo; 1; end; Foo.foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_false
  end
end
