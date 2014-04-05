#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

include Crystal

describe "Type inference: ssa" do
  it "types a redefined variable" do
    assert_type("
      a = 1
      a = 'a'
      a
      ") { char }
  end
end
