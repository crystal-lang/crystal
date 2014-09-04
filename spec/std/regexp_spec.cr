#!/usr/bin/env bin/crystal --run
require "spec"

describe "Regex" do
  it "matches with =~ and captures" do
    ("fooba" =~ /f(o+)(bar?)/).should eq(0)
    MatchData.last.length.should eq(2)
    MatchData.last[1].should eq("oo")
    MatchData.last[2].should eq("ba")
  end

  it "matches with === and captures" do
    "foo" =~ /foo/
    (/f(o+)(bar?)/ === "fooba").should be_true
    MatchData.last.length.should eq(2)
    MatchData.last[1].should eq("oo")
    MatchData.last[2].should eq("ba")
  end

  it "raises if outside match range with []" do
    "foo" =~ /foo/
    expect_raises IndexOutOfBounds do
      MatchData.last[1]
    end
  end

  it "raises if outside match range with begin" do
    "foo" =~ /foo/
    expect_raises IndexOutOfBounds do
      MatchData.last[1]
    end
  end

  it "capture named group" do
    ("fooba" =~ /f(?<g1>o+)(?<g2>bar?)/).should eq(0)
    MatchData.last["g1"].should eq("oo")
    MatchData.last["g2"].should eq("ba")
  end

  it "capture empty group" do
    ("foo" =~ /(?<g1>.*)foo/).should eq(0)
    MatchData.last["g1"].should eq("")
  end

  it "raises exception when named group doesn't exist" do
    ("foo" =~ /foo/).should eq(0)
    expect_raises ArgumentError  { MatchData.last["group"] }
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

  it "raises exception with invalid regex" do
    expect_raises ArgumentError { Regex.new("+") }
  end
end
