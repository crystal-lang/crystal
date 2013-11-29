#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Normalize: def" do
  it "expands a def with default arguments" do
    a_def = parse "def foo(x, y = 1, z = 2); x + y + z; end"
    assert_type a_def, Def

    expanded = a_def.expand_default_arguments

    expanded1 = parse "def foo(x, y, z); x + y + z; end"
    expanded2 = parse "def foo(x, y); foo(x, y, 2); end"
    expanded3 = parse "def foo(x); foo(x, 1); end"

    expanded.should eq([expanded1, expanded2, expanded3])
  end

  it "expands a def with default arguments that yields" do
    a_def = parse "def foo(x, y = 1, z = 2); yield x + y + z; end"
    assert_type a_def, Def

    expanded = a_def.expand_default_arguments

    expanded1 = parse "def foo(x, y, z); yield x + y + z; end"
    expanded2 = parse "def foo(x, y); z = 2; yield x + y + z; end"
    expanded3 = parse "def foo(x); y = 1; z = 2; yield x + y + z; end"

    expanded.should eq([expanded1, expanded2, expanded3])
  end

  it "expands a def with default arguments and type restrictions" do
    a_def = parse "def foo(x, y = 1 : Int32, z = 2 : Int64); x + y + z; end"
    assert_type a_def, Def

    expanded = a_def.expand_default_arguments

    expanded1 = parse "def foo(x, y : Int32, z : Int64); x + y + z; end"
    expanded2 = parse "def foo(x, y : Int32); z = 2; x + y + z; end"
    expanded3 = parse "def foo(x); y = 1; z = 2; x + y + z; end"

    expanded.should eq([expanded1, expanded2, expanded3])
  end
end
