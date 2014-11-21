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
        foo_i32 = foo.instantiate([int32] of TypeVar)
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
        foo_i32 = foo.instantiate([int32] of TypeVar)
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

  it "declares instance var with initial value" do
    assert_type("
      class Foo
        @x = 0

        def x
          @x
        end
      end

      Foo.new.x
      ") { int32 }
  end

  it "declares instance var with initial value, with subclass" do
    assert_type("
      class Foo
        @x = 0

        def x
          @x
        end
      end

      class Bar < Foo
        def initialize
          @z = 1
        end
      end

      Bar.new.x
      ") { int32 }
  end

  it "errors if declaring generic type without type vars" do
    assert_error %(
      class Foo(T)
      end

      x :: Foo
      ),
      "can't declare variable of generic non-instantiated type Foo"
  end

  it "errors if declaring generic type without type vars (with instance var)" do
    assert_error %(
      class Foo(T)
      end

      class Bar
        def initialize
          @x :: Foo
        end
      end

      Bar.new
      ),
      "can't declare variable of generic non-instantiated type Foo"
  end
end
