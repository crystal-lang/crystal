#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Block inference" do
  it "infer type of empty block body" do
    assert_type("
      def foo; yield; end

      foo do
      end
    ") { |mod| mod.nil }
  end

  it "infer type of block body" do
    input = parse "
      def foo; yield; end

      foo do
        x = 1
      end
    "
    result = infer_type input
    assert_type input, Expressions

    call = input.last
    assert_type call, Call
    call.block.not_nil!.body.type.should eq(result.program.int32)
  end
end
