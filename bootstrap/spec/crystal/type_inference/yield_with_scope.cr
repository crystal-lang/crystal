#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: yield with scope" do
  it "infer type of empty block body" do
    assert_type("
      def foo; 1.yield; end

      foo do
      end
    ") { |mod| mod.nil }
  end

  it "infer type of block body" do
    input = parse "
      def foo; 1.yield; end

      foo do
        x = 1
      end
    "
    result = infer_type input
    mod, input = result.program, result.node
    assert_type input, Expressions

    call = input.last
    assert_type call, Call

    assign = call.block.not_nil!.body
    assert_type assign, Assign

    assign.target.type.should eq(mod.int32)
  end

  it "infer type of block body with yield scope" do
    input = parse "
      def foo; 1.yield; end

      foo do
        to_i64
      end
    "
    result = infer_type input
    mod, input = result.program, result.node
    assert_type input, Expressions

    call = input.last
    assert_type call, Call

    call.block.not_nil!.body.type.should eq(mod.int64)
  end

  it "infer type of block body with yield scope and arguments" do
    input = parse "
      def foo; 1.yield 1.5; end

      foo do |f|
        to_i64 + f
      end
    "
    result = infer_type input
    mod, input = result.program, result.node
    assert_type input, Expressions

    call = input.last
    assert_type call, Call

    call.block.not_nil!.body.type.should eq(mod.float64)
  end
end
