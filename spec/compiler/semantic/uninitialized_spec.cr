require "../../spec_helper"

describe "Semantic: uninitialized" do
  it "declares as uninitialized" do
    assert_type("a = uninitialized Int32") { int32 }
  end

  it "declares as uninitialized and reads it" do
    assert_type("a = uninitialized Int32; a") { int32 }
  end

  it "declares an instance variable in initialize as uninitialized" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        def initialize
          @x = uninitialized Int32
        end

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "errors if declaring generic type without type vars (with instance var)" do
    assert_error <<-CRYSTAL, "can't declare variable of generic non-instantiated type Foo"
      class Foo(T)
      end

      class Bar
        def initialize
          @x = uninitialized Foo
        end
      end

      Bar.new
      CRYSTAL
  end

  it "errors if declaring generic type without type vars (with class var)" do
    assert_error <<-CRYSTAL, "can't declare variable of generic non-instantiated type Foo"
      class Foo(T)
      end

      class Bar
        @@x = uninitialized Foo
      end

      Bar.new
      CRYSTAL
  end

  it "errors if declares var and then assigns other type" do
    assert_error <<-CRYSTAL, "type must be Int32, not (Char | Int32)"
      x = uninitialized Int32
      x = 'a'
      CRYSTAL
  end

  it "errors if declaring variable multiple times with different types (#917)" do
    assert_error <<-CRYSTAL, "variable 'buf' already declared with type Int32", inject_primitives: true
      if 1 == 0
        buf = uninitialized Int32
      else
        buf = uninitialized Float64
      end
      CRYSTAL
  end

  it "can uninitialize variable outside initialize (#2828)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        @x = uninitialized Int32

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "can uninitialize variable outside initialize, generic (#2828)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo(T)
        @x = uninitialized T

        def x
          @x
        end
      end

      Foo(Int32).new.x
      CRYSTAL
  end

  it "can use uninitialized with class type (#2940)" do
    assert_type(<<-CRYSTAL) { int32.metaclass }
      class Foo(U)
        def initialize
          @x = uninitialized U
        end

        def x
          @x
        end
      end

      Foo(Int32.class).new.x
      CRYSTAL
  end

  %w(Object Value Reference Number Int Float Struct Class Enum).each do |type|
    it "disallows declaring var of type #{type}" do
      assert_error <<-CRYSTAL, "use a more specific type"
        x = uninitialized #{type}
        CRYSTAL
    end
  end

  it "works with uninitialized NoReturn (#3314)" do
    assert_type(<<-CRYSTAL) { nil_type }
      def foo
        x = uninitialized typeof(yield)
      end

      def bar
        foo { return }
      end

      bar
      CRYSTAL
  end

  it "has type (#3641)" do
    assert_type(<<-CRYSTAL) { int32 }
      x = uninitialized Int32
      CRYSTAL
  end

  it "uses virtual type for uninitialized (#8216)" do
    assert_type(<<-CRYSTAL) { types["Base"].virtual_type! }
      class Base
      end

      class Sub < Base
      end

      u = uninitialized Base
      u
      CRYSTAL
  end
end
