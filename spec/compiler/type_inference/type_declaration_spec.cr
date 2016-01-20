require "../../spec_helper"

describe "Type inference: type declaration" do
  it "declares instance var which appears in initialize" do
    result = assert_type("
      class Foo
        @x : Int32
      end

      Foo.new") { types["Foo"] }

    mod = result.program

    foo = mod.types["Foo"] as NonGenericClassType
    foo.instance_vars["@x"].type.should eq(mod.int32)
  end

  it "declares instance var of generic class" do
    result = assert_type("
      class Foo(T)
        @x : T
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
        @x : T
      end

      f") do
      foo = types["Foo"] as GenericClassType
      foo_i32 = foo.instantiate([int32] of TypeVar)
      foo_i32.lookup_instance_var("@x").type.should eq(int32)
      foo_i32
    end
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

      x : Foo
      ),
      "can't declare variable of generic non-instantiated type Foo"
  end

  it "declares global variable" do
    assert_error %(
      $x : Int32
      $x = true
      ),
      "type must be Int32, not Bool"
  end

  it "declares global variable and reads it (nilable)" do
    assert_error %(
      $x : Int32
      $x
      ),
      "type must be Int32, not Nil"
  end

  it "declares class variable" do
    assert_error %(
      class Foo
        @@x : Int32

        def self.x=(x)
          @@x = x
        end
      end

      Foo.x = true
      ),
      "type must be Int32, not Bool"
  end

  it "declares class variable (2)" do
    assert_error %(
      class Foo
        @@x : Int32

        def self.x
          @@x
        end
      end

      Foo.x
      ),
      "type must be Int32, not Nil"
  end

  # TODO: remove these after 0.11

  it "declares as uninitialized" do
    assert_type("a :: Int32") { |mod| mod.nil }
  end

  it "declares as uninitialized and reads it" do
    assert_type("a :: Int32; a") { int32 }
  end

  it "declares an instance variable in initialize as uninitialized" do
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

  it "errors if declares var and then assigns other type" do
    assert_error %(
      x :: Int32
      x = 1_i64
      ),
      "type must be Int32, not (Int32 | Int64)"
  end

  it "errors if declaring variable multiple times with different types (#917)" do
    assert_error %(
      if 1 == 0
        buf :: Int32
      else
        buf :: Float64
      end
      ),
      "variable 'buf' already declared with type Int32"
  end

  %w(Object Value Reference Number Int Float Struct Class Enum).each do |type|
    it "disallows declaring var of type #{type}" do
      assert_error %(
        x :: #{type}
        ),
        "use a more specific type"
    end
  end
end
