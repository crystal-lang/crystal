require 'spec_helper'

describe "Type clone" do
  let(:mod) { Crystal::Program.new }

  it "clone primitive type" do
    type = mod.int
    type.clone.should be(type)
  end

  it "clone object type" do
    type = ObjectType.new("Foo").with_var("@foo", mod.int)
    type.clone.should eq(type)
  end

  it "clone recursive object type" do
    type = ObjectType.new("Foo")
    type.with_var("@foo", type)
    type_clone = type.clone
    type_clone.should eq(type)
    type_clone.instance_vars["@foo"].type.should be(type_clone)
  end
end