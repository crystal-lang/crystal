#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

include Crystal

describe "Type inference: var" do
  it "types an assign" do
    input = parse "a = 1"
    result = infer_type input
    mod = result.program
    node = result.node as Assign
    node.target.type.should eq(mod.int32)
    node.value.type.should eq(mod.int32)
    node.type.should eq(mod.int32)
  end

  it "types a variable" do
    input = parse "a = 1; a"
    result = infer_type input
    mod = result.program
    node = result.node as Expressions
    node.last.type.should eq(mod.int32)
    node.type.should eq(mod.int32)
  end

  it "reports undefined local variable or method" do
    assert_error "
      def foo
        a = something
      end

      def bar
        foo
      end

      bar
    ", "undefined local variable or method 'something'"
  end

  assert_syntax_error "a += 1",
                      "'+=' before definition of 'a'"

  it "reports read before assignment" do
    assert_error "a = a + 1",
      "undefined local variable or method 'a'"
  end

  it "reports there's no self" do
    assert_error "self", "there's no self in this scope"
  end

  assert_syntax_error "self = 1",
                      "can't change the value of self"

  it "reports variable always nil" do
    assert_error "1 == 2 ? (a = 1) : a",
      "read before definition of 'a'"
  end

  it "lets type on else side of if with a Bool | Nil union" do
    assert_type(%(
      a = (1 == 1) || nil
      a ? nil : a
      )) { nilable bool }
  end
end
