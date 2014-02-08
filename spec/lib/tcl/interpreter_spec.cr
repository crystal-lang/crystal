#!/usr/bin/env bin/crystal --run
require "spec"
require "tcl"

describe "Interpreter" do
  def create_interp
    Tcl::Interpreter.new
  end

  it "should create interpreter" do
    create_interp
  end

  it "should create integers" do
    i = create_interp
    v = i.create_obj 42

    v.is_a?(Tcl::IntObj).should be_true
    v.value.should eq(42)
  end

  it "should update integers value" do
    i = create_interp
    v = i.create_obj 42
    v.value = 35
    v.value.should eq(35)
  end

  it "should create boolean" do
    i = create_interp
    v = i.create_obj true

    v.is_a?(Tcl::BoolObj).should be_true
    v.value.should eq(true)
  end

  it "should update boolean value" do
    i = create_interp
    v = i.create_obj true
    v.value = false
    v.value.should eq(false)
  end

  it "should create empty list" do
    i = create_interp
    v = i.create_obj [] of Int32

    v.is_a?(Tcl::ListObj).should be_true
    v.length.should eq(0)
  end

  it "should append elements to list" do
    i = create_interp
    v = i.create_obj [] of Int32
    e = i.create_obj 42

    v.push e
    v.length.should eq(1)
  end

  it "should create non empty list" do
    i = create_interp
    v = i.create_obj [3,4]
    v.length.should eq(2)
  end

  it "should get element by index" do
    i = create_interp
    v = i.create_obj [3,4]
    v[0].is_a?(Tcl::IntObj).should be_true
    v[0].value.should eq(3)
    v[1].value.should eq(4)
  end

  it "should convert to tcl object" do
    i = create_interp
    42.to_tcl(i).value.should eq(42)
    true.to_tcl(i).value.should be_true
    false.to_tcl(i).value.should be_false
  end
end
