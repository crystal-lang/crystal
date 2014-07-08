#!/usr/bin/env bin/crystal --run
require "spec"

describe "Regex" do
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
    rescue ex : IndexOutOfBounds
    end
  end

  it "raises if outside match range with begin" do
    "foo" =~ /foo/
    begin
      $1
      fail "Expected $1 to raise"
    rescue ex : IndexOutOfBounds
    end
  end

  it "capture named group" do
    ("fooba" =~ /f(?<g1>o+)(?<g2>bar?)/).should eq(0)
    $~["g1"].should eq("oo")
    $~["g2"].should eq("ba")
  end

  it "matches multiline" do
    ("foo\n<bar\n>baz" =~ /<bar.*?>/).should be_nil
    ("foo\n<bar\n>baz" =~ /<bar.*?>/m).should eq(4)
  end

  it "matches ignore case" do
    ("HeLlO" =~ /hello/).should be_nil
    ("HeLlO" =~ /hello/i).should eq(0)
  end

  it "does to_s" do
    /foo/.to_s.should eq("/foo/")
    /f(o)(x)/.match("fox").to_s.should eq(%(MatchData("fox" ["o", "x"])))
  end
end
