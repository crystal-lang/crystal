#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: class" do
  it "types Const#allocate" do
    assert_type("class Foo; end; Foo.allocate") { types["Foo"] }
  end

  it "types Const#new" do
    assert_type("class Foo; end; Foo.new") { types["Foo"] }
  end

  it "types Const#new#method" do
    assert_type("class Foo; def coco; 1; end; end; Foo.new.coco") { int32 }
  end

  it "types class inside class" do
    assert_type("class Foo; class Bar; end; end; Foo::Bar.allocate") { types["Foo"].types["Bar"] }
  end

  it "types instance variable" do
    result = assert_type("
      class Foo
        def initialize(coco)
          @coco = coco
        end
      end

      f = Foo.new(2)
      f
    ") { types["Foo"] }
    type = result.node.type
    assert_type type, InstanceVarContainer
    type.instance_vars["@coco"].type.should eq(result.program.int32)
  end

  it "types nilable instance variable" do
    assert_type("
      class Foo
        def coco
          @coco
        end
      end

      f = Foo.new
      f.coco
    ") { |mod| mod.nil }
  end

  it "types nilable instance variable 2" do
    assert_type("
      class Foo
        def coco=(coco)
          @coco = coco
        end
        def coco
          @coco
        end
      end

      f = Foo.new
      f.coco = 1
      f.coco
    ") { |mod| union_of(mod.nil, int32) }
  end
end
