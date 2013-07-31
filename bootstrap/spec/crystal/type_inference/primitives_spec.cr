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

  it "types an int32" do
    assert_type("1") { |mod| mod.int32 }
  end

  it "types a int64" do
    assert_type("1_i64") { |mod| mod.int64 }
  end

  it "types a float32" do
    assert_type("2.3f") { |mod| mod.float32 }
  end

  it "types a float64" do
    assert_type("2.3") { |mod| mod.float64 }
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
