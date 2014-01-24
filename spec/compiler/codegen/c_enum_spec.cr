#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

CodeGenEnumString = "lib Foo; enum Bar; X, Y, Z = 10, W; end end"

describe "Code gen: enum" do
  it "codegens enum value" do
    run("#{CodeGenEnumString}; Foo::Bar::X").to_i.should eq(0)
  end

  it "codegens enum value 2" do
    run("#{CodeGenEnumString}; Foo::Bar::Y").to_i.should eq(1)
  end

  it "codegens enum value 3" do
    run("#{CodeGenEnumString}; Foo::Bar::Z").to_i.should eq(10)
  end

  it "codegens enum value 4" do
    run("#{CodeGenEnumString}; Foo::Bar::W").to_i.should eq(11)
  end
end
