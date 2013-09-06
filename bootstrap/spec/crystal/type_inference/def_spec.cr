#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

include Crystal

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
end
