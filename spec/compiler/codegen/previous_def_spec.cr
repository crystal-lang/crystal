#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "codegen: previous_def" do
  it "codegens previous def" do
    run(%(
      def foo
        1
      end

      def foo
        previous_def + 1
      end

      foo
      )).to_i.should eq(2)
  end
end
