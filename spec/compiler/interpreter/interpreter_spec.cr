#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Interpreter" do
  it "interprets nil" do
    assert_interpret_primitive "nil", nil, &.nil
  end

  it "interprets a true bool" do
    assert_interpret_primitive "true", true, &.bool
  end

  it "interprets a false bool" do
    assert_interpret_primitive "false", false, &.bool
  end

  it "interprets a char" do
    assert_interpret_primitive "'a'", 'a', &.char
  end

  it "interprets an integer" do
    assert_interpret_primitive "1", 1, &.int32
  end

  it "interprets a float" do
    assert_interpret_primitive "2.5", 2.5, &.float64
  end

  it "interprets a symbol" do
    assert_interpret_primitive ":foo", "foo", &.symbol
  end

  it "interprets var assignment and read" do
    assert_interpret_primitive "a = 1; false; a", 1, &.int32
  end

  it "interprets a string" do
    assert_interpret("\"hello\"") do |value|
      value = value as Interpreter::ClassValue
      value.type.should eq(string)

      c = value["@c"] as Interpreter::PrimitiveValue
      c.type.should eq(char)

      length = value["@length"] as Interpreter::PrimitiveValue
      length.type.should eq(int32)
      length.value.should eq(5)
    end
  end

  it "interprets an if that is true" do
    assert_interpret_primitive "true ? 1 : 2", 1, &.int32
  end

  it "interprets an if that is false" do
    assert_interpret_primitive "false ? 1 : 2", 2, &.int32
  end

  it "interprets an if that is nil" do
    assert_interpret_primitive "nil ? 1 : 2", 2, &.int32
  end

  it "interprets a def and a call" do
    assert_interpret_primitive "def foo; 1; end; 2; foo", 1, &.int32
  end

  it "interprets a def and a call with self" do
    assert_interpret_primitive "class Int32; def foo; self; end; end; 1.foo", 1, &.int32
  end

  it "interprets primitive +" do
    assert_interpret_primitive "1 + 2", 3, &.int32
  end

  it "interprets primitive -" do
    assert_interpret_primitive "1 - 2", -1, &.int32
  end

  it "interprets primitive >" do
    assert_interpret_primitive "2 > 1", true, &.bool
  end

  it "interprets primitive ==" do
    assert_interpret_primitive "1 == 1", true, &.bool
  end

  it "interprets primitive <<" do
    assert_interpret_primitive "1 << 2", 4, &.int32
  end

  it "interprets primitive cast" do
    assert_interpret_primitive "1.to_i8", 1_i8, &.int8
  end

  it "interprets a while" do
    assert_interpret_primitive "a = 0; while a < 10; a += 1; end; a", 10, &.int32
  end

  it "interprets class allocate" do
    assert_interpret("Reference.allocate") do |value|
      value = value as Interpreter::ClassValue
      value.type.should eq(reference)
      value.vars.empty?.should be_true
    end
  end

  it "interprets class new" do
    assert_interpret("
      class Foo
      end
      Foo.new
      ") do |value|
      value = value as Interpreter::ClassValue
      value.type.should eq(types["Foo"])
      value.vars.empty?.should be_true
    end
  end

  it "interprets class new with instance var" do
    assert_interpret("
      class Foo
        def initialize(@x)
        end
      end
      Foo.new(1)
      ") do |value|
      value = value as Interpreter::ClassValue
      value.type.should eq(types["Foo"])
      x = value.vars["@x"] as Interpreter::PrimitiveValue
      x.type.should eq(int32)
      x.value.should eq(1)
    end
  end

  it "interprets class new with instance var and generic type" do
    assert_interpret("
      class Foo(T)
        def initialize(@x : T)
        end
      end
      Foo.new(1)
      ") do |value|
      foo = types["Foo"] as GenericClassType
      foo_int32 = foo.instantiate([int32] of Type | ASTNode)

      value = value as Interpreter::ClassValue
      value.type.should eq(foo_int32)

      x = value.vars["@x"] as Interpreter::PrimitiveValue
      x.type.should eq(int32)
      x.value.should eq(1)
    end
  end

  it "interprets class read instance variable" do
    assert_interpret_primitive "
      class Foo
        def initialize(@x)
        end
        def x
          @x
        end
      end
      Foo.new(1).x
      ", 1, &.int32
  end

  it "interprets class read instance variable calling another method" do
    assert_interpret_primitive "
      class Foo
        def initialize(@x)
        end
        def z
          x
        end
        def x
          @x
        end
      end
      Foo.new(1).z
      ", 1, &.int32
  end

  it "interprets call with block without args" do
    assert_interpret_primitive "
      def foo
        yield
      end

      foo { 1 }
      ", 1, &.int32
  end

  it "interprets call with block and args" do
    assert_interpret_primitive "
      def foo
        yield 1, 2
      end

      foo { |x, y| x + y }
      ", 3, &.int32
  end

  it "interprets call with block many times and accesses outer var" do
    assert_interpret_primitive "
      def foo
        yield 1
        yield 2
        yield 3
      end

      a = 0
      foo { |x| a += x }
      a
      ", 6, &.int32
  end
end
