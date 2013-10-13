#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Code gen: class" do
  it "codegens instace method with allocate" do
    run("class Foo; def coco; 1; end; end; Foo.allocate.coco").to_i.should eq(1)
  end

  pending "codegens instace method with new and instance var" do
    run("class Foo; def initialize; @coco = 2; end; def coco; @coco = 1; @coco; end; end; f = Foo.new; f.coco").to_i.should eq(1)
  end

  it "codegens instace method with new" do
    run("class Foo; def coco; 1; end; end; Foo.new.coco").to_i.should eq(1)
  end

  it "codegens call to same instance" do
    run("class Foo; def foo; 1; end; def bar; foo; end; end; Foo.new.bar").to_i.should eq(1)
  end
end
