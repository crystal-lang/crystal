#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Normalize: string interpolation" do
  it "normalizes string interpolation" do
    assert_normalize "\"foo\#{bar}baz\"", "((((::StringBuilder.new) << \"foo\") << bar()) << \"baz\").to_s"
  end
end
