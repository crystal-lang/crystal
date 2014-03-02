#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: closure" do
  it "gives error when using outside variable inside fun literal" do
    assert_error "x = 1; -> { x }", "undefined local variable or method 'x'"
  end

  ["yield", "return"].each do |keyword|
    it "gives error when doing #{keyword} inside fun literal" do
      assert_error "-> { #{keyword} }", "can't #{keyword} from function literal"
    end
  end
end
