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

      class Baz
        @x : Foo
      end
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
      "type must be Int32, not Nil"
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

  it "errors (for now) when typing a local variable" do
    assert_error %(
      x : Int32
      ),
      "declaring the type of a local variable is not yet supported"
  end

  it "errors when typing an instance variable inside a method" do
    assert_error %(
      def foo
        @x : Int32
      end

      foo
      ),
      "declaring the type of an instance variable must be done at the class level"
  end

  it "errors when typing a class variable inside a method" do
    assert_error %(
      def foo
        @@x : Int32
      end

      foo
      ),
      "declaring the type of a class variable must be done at the class level"
  end

  it "errors when typing a global variable inside a method" do
    assert_error %(
      def foo
        $x : Int32
      end

      foo
      ),
      "declaring the type of a global variable must be done at the class level"
  end

  it "declares instance var with union type with a virtual member" do
    assert_type("
      class Parent; end
      class Child < Parent; end

      class Foo
        @x : Parent?

        def x
          @x
        end
      end

      Foo.new.x") { |mod| mod.union_of(mod.types["Parent"].virtual_type!, mod.nil) }
  end
end
