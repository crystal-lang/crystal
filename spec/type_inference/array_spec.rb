require 'spec_helper'

describe 'Type inference: array' do
  it "types array literal of int" do
    assert_type(%q(require "array"; [1, 2, 3])) { array_of(int32) }
  end

  it "types array literal of union" do
    assert_type(%q(require "array"; [1, 2.5])) { array_of(union_of int32, float64) }
  end

  it "types empty typed array literal of int" do
    assert_type(%q(require "array"; [] of Int32)) { array_of(int32) }
  end

  it "types non-empty typed array literal of int" do
    assert_type(%q(require "array"; [1, 2, 3] of Int32)) { array_of(int32) }
  end

  it "types array literal length correctly" do
    assert_type(%q(require "array"; [1].length)) { int32 }
  end
end
