#!/usr/bin/env bin/crystal -run
require "spec"

describe "Regexp" do
  it "matches with =~ and captures" do
    ("fooba" =~ /f(o+)(bar?)/).should eq(0)
    $~.length.should eq(2)
    $1.should eq("oo")
    $2.should eq("ba")
  end

  it "matches with === and captures" do
    "foo" =~ /foo/
    (/f(o+)(bar?)/ === "fooba").should be_true
    $~.length.should eq(2)
    $1.should eq("oo")
    $2.should eq("ba")
  end

  it "raises if outside match range with []" do
    "foo" =~ /foo/
    begin
      $1
      fail "Expected $1 to raise"
    rescue ex : Array::IndexOutOfBounds
    end
  end

  it "raises if outside match range with begin" do
    "foo" =~ /foo/
    begin
      $1
      fail "Expected $1 to raise"
    rescue ex : Array::IndexOutOfBounds
    end
  end
end
