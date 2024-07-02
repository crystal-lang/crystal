require "../../spec_helper"

describe "Semantic: uninitialized" do
  it "declares as uninitialized" do
    assert_type("a = uninitialized Int32") { int32 }
  end

  it "declares as uninitialized and reads it" do
    assert_type("a = uninitialized Int32; a") { int32 }
  end

  it "declares an instance variable in initialize as uninitialized" do
    assert_type("
      class Foo
        def initialize
          @x = uninitialized Int32
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
          @x = uninitialized Foo
        end
      end

      Bar.new
      ),
      "can't declare variable of generic non-instantiated type Foo"
  end

  it "errors if declaring generic type without type vars (with class var)" do
    assert_error %(
      class Foo(T)
      end

      class Bar
        @@x = uninitialized Foo
      end

      Bar.new
      ),
      "can't declare variable of generic non-instantiated type Foo"
  end

  it "errors if declares var and then assigns other type" do
    assert_error %(
      x = uninitialized Int32
      x = 'a'
      ),
      "type must be Int32, not (Char | Int32)"
  end

  it "errors if declaring variable multiple times with different types (#917)" do
    assert_error %(
      if 1 == 0
        buf = uninitialized Int32
      else
        buf = uninitialized Float64
      end
      ),
      "variable 'buf' already declared with type Int32", inject_primitives: true
  end

  it "can uninitialize variable outside initialize (#2828)" do
    assert_type(%(
      class Foo
        @x = uninitialized Int32

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "can uninitialize variable outside initialize, generic (#2828)" do
    assert_type(%(
      class Foo(T)
        @x = uninitialized T

        def x
          @x
        end
      end

      Foo(Int32).new.x
      )) { int32 }
  end

  it "can use uninitialized with class type (#2940)" do
    assert_type(%(
      class Foo(U)
        def initialize
          @x = uninitialized U
        end

        def x
          @x
        end
      end

      Foo(Int32.class).new.x
      )) { int32.metaclass }
  end

  %w(Object Value Reference Number Int Float Struct Class Enum).each do |type|
    it "disallows declaring var of type #{type}" do
      assert_error %(
        x = uninitialized #{type}
        ),
        "use a more specific type"
    end
  end

  it "works with uninitialized NoReturn (#3314)" do
    assert_type(%(
      def foo
        x = uninitialized typeof(yield)
      end

      def bar
        foo { return }
      end

      bar
      )) { nil_type }
  end

  it "has type (#3641)" do
    assert_type(%(
      x = uninitialized Int32
      )) { int32 }
  end

  it "uses virtual type for uninitialized (#8216)" do
    assert_type(%(
      class Base
      end

      class Sub < Base
      end

      u = uninitialized Base
      u
      )) { types["Base"].virtual_type! }
  end
end
