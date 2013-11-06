#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: macro" do
  it "types macro" do
    input = parse "macro foo; \"1\"; end; foo"
    result = infer_type input
    node = result.node
    assert_type node, Expressions

    call = node.last
    assert_type call, Call

    call.target_macro.should eq(parse "1")
  end
end
