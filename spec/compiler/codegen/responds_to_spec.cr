#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Codegen: responds_to?" do
  it "codegens responds_to? true for simple type" do
    run("1.responds_to?(:\"+\")").to_b.should be_true
  end

  it "codegens responds_to? false for simple type" do
    run("1.responds_to?(:foo)").to_b.should be_false
  end

  it "codegens responds_to? with union gives true" do
    run("(1 == 1 ? 1 : 'a').responds_to?(:\"+\")").to_b.should be_true
  end

  it "codegens responds_to? with union gives false" do
    run("(1 == 1 ? 1 : 'a').responds_to?(:\"foo\")").to_b.should be_false
  end

  it "codegens is_a? with nilable gives true" do
    run("struct Nil; def foo; end; end; (1 == 1 ? nil : Reference.new).responds_to?(:foo)").to_b.should be_true
  end

  it "codegens is_a? with nilable gives false becuase other type 1" do
    run("(1 == 1 ? nil : Reference.new).responds_to?(:foo)").to_b.should be_false
  end

  it "codegens is_a? with nilable gives false becuase other type 2" do
    run("class Reference; def foo; end; end; (1 == 2 ? nil : Reference.new).responds_to?(:foo)").to_b.should be_true
  end
end
