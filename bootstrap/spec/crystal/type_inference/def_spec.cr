#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: def" do
  it "types a call with an int" do
    assert_type("def foo; 1; end; foo") { int32 }
  end

  it "types a call with an argument" do
    assert_type("def foo(x); x; end; foo(1)") { int32 }
  end

  it "types a call with an argument uses a new scope" do
    assert_type("x = 2.3; def foo(x); x; end; foo 1; x") { float64 }
  end

  it "assigns def owner" do
    input = parse "class Int32; def foo; 2.5; end; end; 1.foo"
    result = infer_type input
    program, input = result.program, result.node
    fail "Expected #{input} to be an Expressions" unless input.is_a?(Expressions)

    a_def = input.last
    fail "Expected #{a_def} to be a Call" unless a_def.is_a?(Call)

    a_def.target_def.owner.should eq(program.int32)
  end

  # it "allows recursion" do
  #   assert_type("def foo; foo; end; foo") { |mod| mod.nil }
  # end

  it "types a call to a class method 1" do
    assert_type("class Foo; def self.foo; 1; end; end; Foo.foo") { int32 }
  end

  it "types a call to a class method 2" do
    assert_type("class Foo; end; def Foo.foo; 1; end; Foo.foo") { int32 }
  end

  it "raises on undefined local variable or method" do
    assert_error("foo", "undefined local variable or method 'foo'")
  end
end
