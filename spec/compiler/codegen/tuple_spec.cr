#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Code gen: tuple" do
  it "codegens tuple length" do
    run("{1, 2}.length").to_i.should eq(2)
  end

  it "codegens tuple [0]" do
    run("{1, true}[0]").to_i.should eq(1)
  end

  it "codegens tuple [1]" do
    run("{1, true}[1]").to_b.should be_true
  end

  it "codegens tuple [1] (2)" do
    run("{true, 3}[1]").to_i.should eq(3)
  end

  it "codegens tuple indexer (1)" do
    run("
      require \"prelude\"

      x = 1
      {nil, 3}[x].to_i
      ").to_i.should eq(3)
  end

  it "codegens tuple indexer (2)" do
    run("
      require \"prelude\"

      x = 0
      {nil, 3}[x].to_i
      ").to_i.should eq(0)
  end

  it "codegens tuple indexer out of bounds" do
    run("
      require \"prelude\"

      x = 2
      begin
        {nil, 3}[x]
        1
      rescue
        2
      end
      ").to_i.should eq(2)
  end

  it "passed tuple to def" do
    run("
      def foo(t)
        t[1]
      end

      foo({1, 2, 3})
      ").to_i.should eq(2)
  end
end
