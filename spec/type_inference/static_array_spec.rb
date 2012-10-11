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

  it "creates a new typed array of int (setter)" do
    assert_type("a = StaticArray.new(1); a[0] = 1; a") { StaticArrayType.new.of(int) }
  end

  it "creates a new typed array of union" do
    assert_type("a = StaticArray.new(1); a[0] = 1; a[0] = 2.5; a") { StaticArrayType.new.of(UnionType.new(int, float)) }
  end

  it "creates a new typed array of int (getter)" do
    assert_type("a = StaticArray.new(1); a[0] = 1; a[0]") { int }
  end

end
