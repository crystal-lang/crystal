require 'spec_helper'

describe "ast nodes" do
  it "should to_s Int" do
    5.int.to_s.should eq('5')
  end

  it "should to_s Float" do
    5.0.float.to_s.should eq('5.0')
  end

  it "should to_s True" do
    true.bool.to_s.should eq('true')
  end

  it "should to_s False" do
    false.bool.to_s.should eq('false')
  end

  [
    "+",
    "-",
    "*",
    "/",
    "<",
    "<=",
    "==",
    ">",
    ">=",
  ].each do |op|
    it "should to_s Call #{op}" do
      Call.new(5.int, op.to_sym, [6.int]).to_s.should eq("5 #{op} 6")
    end
  end

  it "should to_s Def with no args" do
    Def.new("foo", [], [1.int]).to_s.should eq("def foo\n  1\nend")
  end

  it "should to_s Def with args" do
    Def.new("foo", ['var'.arg], [1.int]).to_s.should eq("def foo(var)\n  1\nend")
  end

  it "should to_s Def with many expressions" do
    Def.new("foo", [], [1.int, 2.int]).to_s.should eq("def foo\n  1\n  2\nend")
  end

  it "should to_s Var" do
    "foo".var.to_s.should eq("foo")
  end

  it "should to_s Call with no args" do
    Call.new(nil, "foo").to_s.should eq("foo()")
  end

  it "should to_s Call with args" do
    Call.new(nil, "foo", [1.int, 2.int]).to_s.should eq("foo(1, 2)")
  end

  it "should to_s Call with no block" do
    Call.new(nil, "foo", [], Block.new).to_s.should eq("foo() do\nend")
  end

  it "should to_s If" do
    If.new("foo".var, 1.int).to_s.should eq("if foo\n  1\nend")
  end

  it "should to_s Not" do
    Call.new("foo".var, :'!@').to_s.should eq("!(foo)")
  end

  ['return', 'break', 'next', 'yield'].each do |keyword|
    it "should to_s #{keyword.capitalize}" do
      eval(keyword.capitalize).new(["foo".var, 1.int]).to_s.should eq("#{keyword} foo, 1")
    end
  end
end
