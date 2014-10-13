#!/usr/bin/env crystal --run
require "../../spec_helper"

describe "ASTNode#to_s" do
  it "puts parenthesis after array literal of T followed by call" do
    Parser.parse("([] of T).foo").to_s.should eq("([] of T).foo")
  end

  it "puts parenthesis after hash literal of T followed by call" do
    Parser.parse("({} of K => V).foo").to_s.should eq("({} of K => V).foo")
  end

  it "doesn't put parenthesis on call if it doesn't have parenthesis" do
    Parser.parse("foo(bar)").to_s.should eq("foo(bar)")
  end

  it "puts parenthesis in ~" do
    Parser.parse("(~1).foo").to_s.should eq("(~1).foo")
  end

  it "puts parenthesis in if && has assign on right hand side" do
    Parser.parse("1 && (a = 2)").to_s.should eq("1 && (a = 2)")
  end

  it "puts parenthesis in if && has assign on left hand side" do
    Parser.parse("(a = 2) && 1").to_s.should eq("(a = 2) && 1")
  end

  it "puts parenthesis in call argument if it's a cast" do
    Parser.parse("foo(a as Int32)").to_s.should eq("foo((a as Int32))")
  end

  it "correctly convert a symbol that doesn't need qoutes" do
    Parser.parse(%(:foo)).to_s.should eq(%(:foo))
  end

  it "correctly convert a symbol that needs qoutes" do
    Parser.parse(%(:"{")).to_s.should eq(%(:"{"))
  end
end
