#!/usr/bin/env bin/crystal -run
require "spec"
require "../../spec_helper"
require "../../../../bootstrap/crystal/parser"
require "../../../../bootstrap/crystal/type_inference"

include Crystal

describe "Type inference: primitives" do
  it "types a bool" do
    assert_type("false") { |mod| mod.bool }
  end

  it "types an int" do
    assert_type("1") { |mod| mod.int }
  end

  it "types a long" do
    assert_type("1L") { |mod| mod.long }
  end

  it "types a float" do
    assert_type("2.3f") { |mod| mod.float }
  end

  it "types a double" do
    assert_type("2.3") { |mod| mod.double }
  end

  it "types a char" do
    assert_type("'a'") { |mod| mod.char }
  end

  it "types a symbol" do
    assert_type(":foo") { |mod| mod.symbol }
  end

  # it "types an expression" do
  #   input = Parser.parse "1; 1.1"
  #   mod = infer_type input
  #   input.type.should eq(mod.double)
  # end
end