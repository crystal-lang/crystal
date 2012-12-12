require 'spec_helper'

describe 'Type inference: def new type' do
  it "it not a new type if no alloc" do
    nodes = parse "def foo; 1; end; foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_false
  end

  it "it is a new type if alloc" do
    nodes = parse "def foo; Object.alloc; end; foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_true
  end

  it "it is a new type if alloc and assigned to var" do
    nodes = parse "def foo; x = Object.alloc; x; end; foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_true
  end

  it "it is a new type if alloc and assigned to var and assigned to something else" do
    nodes = parse "def foo; x = Object.alloc; if false; x = 1; end; x; end; foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_true
  end

  it "it is a new type if new and assigned to var" do
    nodes = parse "def foo; x = Object.new; x; end; foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_true
  end

  it "it is not a new type if static method no alloc" do
    nodes = parse "def Object.foo; 1; end; Object.foo"
    mod = infer_type nodes
    nodes.last.target_def.creates_new_type.should be_false
  end
end
