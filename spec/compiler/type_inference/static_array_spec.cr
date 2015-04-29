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

  it "types static array new with size being a constant" do
    assert_type(%(
      SIZE = 3
      x = StaticArray(Char, SIZE).new
      x
      )) { static_array_of(char, 3) }
  end

  it "types static array new with size being a computed constant" do
    assert_type(%(
      OTHER = 10
      SIZE = OTHER * 20
      x = StaticArray(Char, SIZE).new
      x
      )) { static_array_of(char, 200) }
  end

  it "types staic array new with size being a computed constant, and use N (bug)" do
    assert_type(%(
      struct StaticArray(T, N)
        def length
          N
        end
      end

      SIZE = 1 * 2
      x :: UInt8[SIZE]
      x.length
      a = 1
      )) { int32 }
  end

  it "doesn't crash on restriction (#584)" do
    assert_error %(
      def foo(&block : Int32[Int32] -> Int32)
        block.call([0])
      end

      foo { |x| 0 }
      ),
      "can't instantiate StaticArray(T, N) with N = Int32 (N must be an integer)"
  end
end
