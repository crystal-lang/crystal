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
end
