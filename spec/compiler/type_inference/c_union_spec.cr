#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: c union" do
  it "types c union" do
    result = assert_type("lib Foo; union Bar; x : Int32; y : Float64; end; end; Foo::Bar") { types["Foo"].types["Bar"].metaclass }
    mod = result.program
    bar = mod.types["Foo"].types["Bar"] as CUnionType
    bar.vars["x"].type.should eq(mod.int32)
    bar.vars["y"].type.should eq(mod.float64)
  end

  it "types Union declare" do
    assert_type("lib Foo; union Bar; x : Int32; y : Float64; end; end; x :: Foo::Bar; x") do
      types["Foo"].types["Bar"]
    end
  end

  it "types Union#new" do
    assert_type("lib Foo; union Bar; x : Int32; y : Float64; end; end; Foo::Bar.new") do
      pointer_of(types["Foo"].types["Bar"])
    end
  end

  it "types union setter" do
    assert_type("lib Foo; union Bar; x : Int32; y : Float64; end; end; bar :: Foo::Bar; bar.x = 1") { int32 }
  end

  it "types union getter" do
    assert_type("lib Foo; union Bar; x : Int32; y : Float64; end; end; bar :: Foo::Bar; bar.x") { int32 }
  end

  it "types union setter via new" do
    assert_type("lib Foo; union Bar; x : Int32; y : Float64; end; end; bar = Foo::Bar.new; bar->x = 1") { int32 }
  end

  it "types union getter" do
    assert_type("lib Foo; union Bar; x : Int32; y : Float64; end; end; bar = Foo::Bar.new; bar->x") { int32 }
  end
end
