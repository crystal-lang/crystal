require "../../spec_helper"

describe "Semantic: static array" do
  it "types static array with var declaration" do
    assert_type("x = uninitialized Char[3]") { nil_type }
  end

  it "types static array new" do
    assert_type("x = StaticArray(Char, 3).new; x") { static_array_of(char, 3) }
  end

  it "types static array with type as size" do
    assert_type("
      class Foo(N)
        def self.foo
          x = uninitialized Char[N]
          x
        end
      end

      Foo(1).foo
      ") { static_array_of(char, 1) }
  end

  it "errors if trying to instantiate static array with N not an integer" do
    assert_error %(
      x = uninitialized Char[Int32]
      ),
      "can't instantiate StaticArray(T, N) with N = Int32 (N must be an integer)"
  end

  it "allows instantiating static array instance var in initialize of generic type" do
    assert_type("
      class Foo(N)
        def initialize
          @x = uninitialized Char[N]
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
      x = uninitialized Int32[-1]
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
        def size
          N
        end
      end

      SIZE = 1 * 2
      x = uninitialized UInt8[SIZE]
      x.size
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

  it "can match N type argument of static array (#1203)" do
    assert_type(%(
      def fn(a : StaticArray(T, N)) forall T, N
        N
      end

      n = uninitialized StaticArray(Int32, 10)
      fn(n)
      )) { int32 }
  end

  it "can match number type argument of static array (#1203)" do
    assert_type(%(
      def fn(a : StaticArray(T, 10)) forall T
        10
      end

      n = uninitialized StaticArray(Int32, 10)
      fn(n)
      )) { int32 }
  end

  it "doesn't match other number type argument of static array (#1203)" do
    assert_error %(
      def fn(a : StaticArray(T, 11)) forall T
        10
      end

      n = uninitialized StaticArray(Int32, 10)
      fn(n)
      ),
      "no overload matches"
  end
end
