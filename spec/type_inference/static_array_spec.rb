require 'spec_helper'

describe 'Type inference: static array' do
  it "creates a new untyped array" do
    assert_type("StaticArray.new(1)") { StaticArrayType.new }
  end

  it "gets static array length" do
    assert_type("StaticArray.new(1).length") { int }
  end

  it "creates a new typed array of int (return value)" do
    assert_type("a = StaticArray.new(1); a[0] = 1") { int }
  end

  it "creates a new typed array of union (return value)" do
    assert_type("a = StaticArray.new(1); a[0] = 1; a[0] = 2.5") { float }
  end

  it "creates a new typed array of int (setter)" do
    assert_type("a = StaticArray.new(1); a[0] = 1; a") { StaticArrayType.of(int) }
  end

  it "creates a new typed array of union" do
    assert_type("a = StaticArray.new(1); a[0] = 1; a[0] = 2.5; a") { StaticArrayType.of(UnionType.new(int, float)) }
  end

  it "creates a new typed array of int (getter)" do
    assert_type("a = StaticArray.new(1); a[0] = 1; a[0]") { int }
  end

  it "creates two static arrays" do
    assert_type("a = StaticArray.new(1); a[0] = 1; b = StaticArray.new(1); b[0] = 2.5; b") { StaticArrayType.of(float) }
  end

  it "types array of arrays" do
    assert_type(%Q(
      a = StaticArray.new 2
      b = StaticArray.new 3
      c = StaticArray.new 3
      a[0] = b
      a[1] = c
      a[0][0] = 1
      c
    )) { StaticArrayType.of(int) }
  end
end
