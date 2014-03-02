#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Normalize: block arg" do
  it "doesn't normalize block arg if not used" do
    assert_normalize "def foo(&block); end", "def foo(&block : -> )\nend"
  end

  # it "normalizes block arg if used" do
  #   assert_normalize "def foo(&block : Int32 -> ); block; end", "def foo(&block : Int32 -> )\n  block = ->(#arg0 : Int32) do\n    yield #arg0\n  end\n  block\nend"
  # end
end
