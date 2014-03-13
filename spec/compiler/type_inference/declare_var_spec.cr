#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: declare var" do
  it "types declare var" do
    assert_type("a :: Int32") { int32 }
  end

  it "types declare var and reads it" do
    assert_type("a :: Int32; a") { int32 }
  end

  it "types declare var and changes its type" do
    assert_type("a :: Int32; while 1 == 2; a = 'a'; end; a") { union_of(int32, char) }
  end

  it "declares instance var which appears in initialize" do
    result = assert_type("
      class Foo
        @x :: Int32
      end

      Foo.new") { types["Foo"] }

    mod = result.program

    foo = mod.types["Foo"] as NonGenericClassType
    foo.instance_vars["@x"].type.should eq(mod.int32)
  end

  it "declares instance var of generic class" do
    result = assert_type("
      class Foo(T)
        @x :: T
      end

      Foo(Int32).new") do
        foo = types["Foo"] as GenericClassType
        foo_i32 = foo.instantiate([int32] of Type | ASTNode)
        foo_i32.lookup_instance_var("@x").type.should eq(int32)
        foo_i32
    end
  end

  it "declares instance var of generic class after reopen" do
    result = assert_type("
      class Foo(T)
      end

      f = Foo(Int32).new

      class Foo(T)
        @x :: T
      end

      f") do
        foo = types["Foo"] as GenericClassType
        foo_i32 = foo.instantiate([int32] of Type | ASTNode)
        foo_i32.lookup_instance_var("@x").type.should eq(int32)
        foo_i32
    end
  end

  it "declares an instance variable in initialize" do
    assert_type("
      class Foo
        def initialize
          @x :: Int32
        end

        def x
          @x
        end
      end

      Foo.new.x
      ") { int32 }
  end
end
