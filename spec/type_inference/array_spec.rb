require 'spec_helper'

describe 'Type inference: array' do
  it "types empty array literal" do
    assert_type("[]") { types['Array'] }
  end

  it "types array literal of int" do
    assert_type("[1, 2, 3]") { array_of(int) }
  end

  it "types array literal of union" do
    assert_type("[1, 2.5]") { array_of([int, float].union) }
  end
end
