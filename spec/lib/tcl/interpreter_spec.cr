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
end
