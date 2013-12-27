#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: macro" do
  it "types macro" do
    input = parse "macro foo; \"1\"; end; foo"
    result = infer_type input
    node = result.node as Expressions
    (node.last as Call).target_macro.should eq(parse "1")
  end
end
