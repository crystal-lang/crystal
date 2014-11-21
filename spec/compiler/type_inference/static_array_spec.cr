require "../../spec_helper"

describe "Type inference: static array" do
  it "types static array with var declaration" do
    assert_type("x :: Char[3]") { static_array_of(char, 3) }
  end

  it "types static array new" do
    assert_type("x = StaticArray(Char, 3).new; x") { static_array_of(char, 3) }
  end

  it "types static array with type as size" do
    assert_type("
      class Foo(N)
        def self.foo
          x :: Char[N]
          x
        end
      end

      Foo(1).foo
      ") { static_array_of(char, 1) }
  end

  it "errors if trying to instantiate static array with N not an integer" do
    assert_error %(
      x :: Char[Int32]
      ),
      "can't instantiate StaticArray(T, N) with N = Int32 (N must be an integer)"
  end

  it "allows instantiating static array instance var in initialize of generic type" do
    assert_type("
      class Foo(N)
        def initialize
          @x :: Char[N]
        end

        def x
          @x
        end
      end

      Foo(1).new.x
      ") { static_array_of(char, 1) }
  end

  it "errors on negative static array size" do
    assert_error %(
      x :: Int32[-1]
      ),
      "can't instantiate StaticArray(T, N) with N = -1 (N must be positive)"
  end
end
