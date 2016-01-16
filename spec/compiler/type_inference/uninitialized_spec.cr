require "../../spec_helper"

describe "Type inference: uninitialized" do
  it "declares as uninitialized" do
    assert_type("a = uninitialized Int32") { |mod| mod.nil }
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

  it "errors if using uninitialize for instance var outside method" do
    assert_error %(
      class Foo
        @a = uninitialized Int32
      end
      ),
      "can't uninitialize instance variable outside method"
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

  it "errors if declares var and then assigns other type" do
    assert_error %(
      x = uninitialized Int32
      x = 1_i64
      ),
      "type must be Int32, not (Int32 | Int64)"
  end

  it "errors if declaring variable multiple times with different types (#917)" do
    assert_error %(
      if 1 == 0
        buf = uninitialized Int32
      else
        buf = uninitialized Float64
      end
      ),
      "variable 'buf' already declared with type Int32"
  end

  %w(Object Value Reference Number Int Float Struct Class Enum).each do |type|
    it "disallows declaring var of type #{type}" do
      assert_error %(
        x = uninitialized #{type}
        ),
        "use a more specific type"
    end
  end
end
