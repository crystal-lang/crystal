require 'spec_helper'

describe 'Type inference: array' do
  it "types array literal of int" do
    assert_type(%q(require "array"; [1, 2, 3])) { array_of(int) }
  end

  it "types array literal of union" do
    assert_type(%q(require "array"; [1, 2.5])) { array_of(union_of int, double) }
  end
end
