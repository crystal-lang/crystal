#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Interpreter" do
  it "interprets nil" do
    assert_interpret("nil") do |value, mod|
      value.type.should eq(mod.nil)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(nil)
    end
  end

  it "interprets a true bool" do
    assert_interpret("true") do |value|
      value.type.should eq(bool)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(true)
    end
  end

  it "interprets a false bool" do
    assert_interpret("false") do |value|
      value.type.should eq(bool)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(false)
    end
  end

  it "interprets a char" do
    assert_interpret("'a'") do |value|
      value.type.should eq(char)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq('a')
    end
  end

  it "interprets an integer" do
    assert_interpret("1") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(1)
    end
  end

  it "interprets a float" do
    assert_interpret("2.5") do |value|
      value.type.should eq(float64)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(2.5)
    end
  end

  it "interprets a symbol" do
    assert_interpret(":foo") do |value|
      value.type.should eq(symbol)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq("foo")
    end
  end

  it "interprets var assignment and read" do
    assert_interpret("a = 1; false; a") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(1)
    end
  end

  it "interprets var assignment and read" do
    assert_interpret("a = 1; false; a") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(1)
    end
  end

  it "interprets a string" do
    assert_interpret("\"hello\"") do |value|
      value.type.should eq(string)
      assert_type value, Interpreter::ClassValue

      c = value["@c"]
      assert_type c, Interpreter::PrimitiveValue
      c.type.should eq(char)

      length = value["@length"]
      assert_type length, Interpreter::PrimitiveValue

      length.type.should eq(int32)
      length.value.should eq(5)
    end
  end

  it "interprets an if that is true" do
    assert_interpret("true ? 1 : 2") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(1)
    end
  end

  it "interprets an if that is false" do
    assert_interpret("false ? 1 : 2") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(2)
    end
  end

  it "interprets an if that is nil" do
    assert_interpret("nil ? 1 : 2") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(2)
    end
  end

  it "interprets a def and a call" do
    assert_interpret("def foo; 1; end; 2; foo") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(1)
    end
  end

  it "interprets a def and a call with self" do
    assert_interpret("class Int32; def foo; self; end; end; 1.foo") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(1)
    end
  end

  it "interprets primitive +" do
    assert_interpret("1 + 2") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(3)
    end
  end

  it "interprets primitive -" do
    assert_interpret("1 - 2") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(-1)
    end
  end

  it "interprets primitive >" do
    assert_interpret("2 > 1") do |value|
      value.type.should eq(bool)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(true)
    end
  end

  it "interprets primitive ==" do
    assert_interpret("1 == 1") do |value|
      value.type.should eq(bool)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(true)
    end
  end

  it "interprets primitive <<" do
    assert_interpret("1 << 2") do |value|
      value.type.should eq(int32)
      assert_type value, Interpreter::PrimitiveValue
      value.value.should eq(4)
    end
  end
end
