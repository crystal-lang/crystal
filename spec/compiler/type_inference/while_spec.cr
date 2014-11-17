#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: while" do
  it "types while" do
    assert_type("while 1; 1; end") { |mod| mod.nil }
  end

  it "types while with break without value" do
    assert_type("while true; break; end") { |mod| mod.nil }
  end

  it "types while with break with value" do
    # This is a change from the compiler written in Ruby
    # assert_type("while true; break 1; end") { |mod| union_of(mod.nil, int32) }
    assert_type("while true; break 1; end") { |mod| mod.nil }
  end

  it "reports break cannot be used outside a while" do
    assert_error "break",
      "Invalid break"
  end

  it "types while true as NoReturn" do
    assert_type("while true; end") { no_return }
  end

  it "reports next cannot be used outside a while" do
    assert_error "next",
      "Invalid next"
  end

  it "uses var type inside while if endless loop" do
    assert_type(%(
      a = nil
      while true
        a = 1
        break
      end
      a
      )) { int32 }
  end

  it "uses var type inside while if endless loop (2)" do
    assert_type(%(
      while true
        a = 1
        break
      end
      a
      )) { int32 }
  end

  it "marks variable as nil if breaking before assigning to it in an endless loop" do
    assert_type(%(
      a = nil
      while true
        break if 1 == 2
        a = 1
      end
      a
      )) { nilable int32 }
  end

  it "marks variable as nil if breaking before assigning to it in an endless loop (2)" do
    assert_type(%(
      while true
        break if 1 == 2
        a = 1
      end
      a
      )) { nilable int32 }
  end
end
