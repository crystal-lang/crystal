#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Normalize: def" do
  it "expands a def on request with default arguments" do
    a_def = parse("def foo(x, y = 1, z = 2); x + y + z; end") as Def
    actual = a_def.expand_default_arguments(1)
    expected = parse("def foo(x); foo(x, 1, 2); end")
    actual.should eq(expected)
  end

  it "expands a def on request with default arguments (2)" do
    a_def = parse("def foo(x, y = 1, z = 2); x + y + z; end") as Def
    actual = a_def.expand_default_arguments(2)
    expected = parse("def foo(x, y); foo(x, y, 2); end")
    actual.should eq(expected)
  end

  it "expands a def on request with default arguments that yields" do
    a_def = parse("def foo(x, y = 1, z = 2); yield x + y + z; end") as Def
    actual = a_def.expand_default_arguments(1)
    expected = parse("def foo(x); y = 1; z = 2; yield x + y + z; end")
    actual.should eq(expected)
  end

  it "expands a def on request with default arguments that yields (2)" do
    a_def = parse("def foo(x, y = 1, z = 2); yield x + y + z; end") as Def
    actual = a_def.expand_default_arguments(2)
    expected = parse("def foo(x, y); z = 2; yield x + y + z; end")
    actual.should eq(expected)
  end

  it "expands a def on request with default arguments and type restrictions" do
    a_def = parse("def foo(x, y = 1 : Int32, z = 2 : Int64); x + y + z; end") as Def
    actual = a_def.expand_default_arguments(1)
    expected = parse("def foo(x); y = 1; z = 2; x + y + z; end")
    actual.should eq(expected)
  end

  it "expands a def on request with default arguments and type restrictions (2)" do
    a_def = parse("def foo(x, y = 1 : Int32, z = 2 : Int64); x + y + z; end") as Def
    actual = a_def.expand_default_arguments(2)
    expected = parse("def foo(x, y : Int32); z = 2; x + y + z; end")
    actual.should eq(expected)
  end

  it "expands with splat" do
    a_def = parse("def foo(*args); args; end") as Def
    actual = a_def.expand_default_arguments(3)
    expected = parse("def foo(_arg0, _arg1, _arg2)\n  args = {_arg0, _arg1, _arg2}\n  args\nend")
    actual.should eq(expected)
  end

  it "expands with splat with one arg before" do
    a_def = parse("def foo(x, *args); args; end") as Def
    actual = a_def.expand_default_arguments(3)
    expected = parse("def foo(x, _arg0, _arg1)\n  args = {_arg0, _arg1}\n  args\nend")
    actual.should eq(expected)
  end

  it "expands with splat with one arg after" do
    a_def = parse("def foo(*args, x); args; end") as Def
    actual = a_def.expand_default_arguments(3)
    expected = parse("def foo(_arg0, _arg1, x)\n  args = {_arg0, _arg1}\n  args\nend")
    actual.should eq(expected)
  end

  it "expands with splat with one arg before and after" do
    a_def = parse("def foo(x, *args, z); args; end") as Def
    actual = a_def.expand_default_arguments(3)
    expected = parse("def foo(x, _arg0, z)\n  args = {_arg0}\n  args\nend")
    actual.should eq(expected)
  end
end
