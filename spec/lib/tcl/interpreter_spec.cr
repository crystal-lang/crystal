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

  it "should create strings" do
    i = create_interp
    v = i.create_obj "lorem"

    v.is_a?(Tcl::StringObj).should be_true
    v.value.should eq("lorem")
  end

  it "should update string value" do
    i = create_interp
    v = i.create_obj "lorem"
    v.value = "ipsum"
    v.value.should eq("ipsum")
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

  it "should get element by index with mixed types" do
    i = create_interp
    v = i.create_obj [3,"foo",false]
    v[0].is_a?(Tcl::IntObj).should be_true
    v[1].is_a?(Tcl::StringObj).should be_true
    v[2].is_a?(Tcl::BoolObj).should be_true
    v[0].value.should eq(3)
    v[1].value.should eq("foo")
    v[2].value.should eq(false)
  end

  it "should convert to tcl object" do
    i = create_interp
    42.to_tcl(i).value.should eq(42)
    true.to_tcl(i).value.should be_true
    false.to_tcl(i).value.should be_false
    "foo".to_tcl(i).value.should eq("foo")
  end

  def tcl_type(i, v)
    Tcl.type_name(v.to_tcl(i).lib_obj)
  end

  it "should keep ObjType" do
    i = create_interp
    tcl_type(i, 35).should eq(tcl_type(i, 23))
  end
end
