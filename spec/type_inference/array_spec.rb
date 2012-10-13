require 'spec_helper'

describe 'Type inference: array' do
  it "types empty array literal" do
    assert_type("[]") { ArrayType.new }
  end

  it "types array literal" do
    assert_type("[].length") { int }
  end

  it "types array literal of int" do
    assert_type("[1, 2, 3]") { ArrayType.of(int) }
  end

  it "types array literal of union" do
    assert_type("[1, 2.5]") { ArrayType.of([int, float].union) }
  end

  it "types array getter" do
    assert_type("a = [1, 2]; a[0]") { int }
  end

  it "types array setter" do
    assert_type("a = [1, 2]; a[0] = 1") { int }
  end

  it "types array union" do
    assert_type("a = [1, 2]; a[0] = 1; a[1] = 2.5; a") { ArrayType.of([int, float].union) }
  end
end
