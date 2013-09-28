#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Type inference: lib" do
  it "raises on undefined fun" do
    assert_error("lib C; end; C.foo", "undefined fun 'foo' for C")
  end
end
