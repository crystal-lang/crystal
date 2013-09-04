#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

include Crystal

describe "Type inference: def" do
  it "types a call with an int" do
    assert_type("def foo; 1; end; foo") { int32 }
  end
end
