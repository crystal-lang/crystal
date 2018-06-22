require "../../spec_helper"

describe "Semantic: automatic cast" do
  it "casts literal integer (Int32 -> no restriction)" do
    assert_type(%(
      def foo(x)
        x + 1
      end

      foo(12345)
      ), inject_primitives: true) { int32 }
  end

  it "casts literal integer (Int32 -> Int64)" do
    assert_type(%(
      def foo(x : Int64)
        x
      end

      foo(12345)
      )) { int64 }
  end

  it "casts literal integer (Int64 -> Int32, ok)" do
    assert_type(%(
      def foo(x : Int32)
        x
      end

      foo(2147483647_i64)
      )) { int32 }
  end

  it "casts literal integer (Int64 -> Int32, too big)" do
    assert_error %(
      def foo(x : Int32)
        x
      end

      foo(2147483648_i64)
      ),
      "no overload matches"
  end

  it "casts literal integer (Int32 -> Float32)" do
    assert_type(%(
      def foo(x : Float32)
        x
      end

      foo(12345)
      )) { float32 }
  end

  it "casts literal integer (Int32 -> Float64)" do
    assert_type(%(
      def foo(x : Float64)
        x
      end

      foo(12345)
      )) { float64 }
  end

  it "casts literal float (Float32 -> Float64)" do
    assert_type(%(
      def foo(x : Float64)
        x
      end

      foo(1.23_f32)
      )) { float64 }
  end

  it "casts literal float (Float64 -> Float32)" do
    assert_type(%(
      def foo(x : Float32)
        x
      end

      foo(1.23)
      )) { float32 }
  end

  it "matches correct overload" do
    assert_type(%(
      def foo(x : Int32)
        x
      end

      def foo(x : Int64)
        x
      end

      foo(1_i64)
      )) { int64 }
  end

  it "casts literal integer through alias with union" do
    assert_type(%(
      alias A = Int64 | String

      def foo(x : A)
        x
      end

      foo(12345)
      )) { int64 }
  end

  it "says ambiguous call for integer" do
    assert_error %(
      def foo(x : Int8)
        x
      end

      def foo(x : UInt8)
        x
      end

      foo(1)
      ),
      "ambiguous"
  end

  it "says ambiguous call for integer (2)" do
    assert_error %(
      def foo(x : Int8 | UInt8)
        x
      end

      foo(1)
      ),
      "ambiguous"
  end

  it "casts symbol literal to enum" do
    assert_type(%(
      enum Foo
        One
        Two
        Three
      end

      def foo(x : Foo)
        x
      end

      foo(:one)
      )) { types["Foo"] }
  end

  it "casts literal integer through alias with union" do
    assert_type(%(
      enum Foo
        One
        Two
      end

      alias A = Foo | String

      def foo(x : A)
        x
      end

      foo(:two)
      )) { types["Foo"] }
  end

  it "errors if symbol name doesn't match enum member" do
    assert_error %(
      enum Foo
        One
        Two
        Three
      end

      def foo(x : Foo)
        x
      end

      foo(:four)
      ),
      "no overload matches"
  end

  it "says ambiguous call for symbol" do
    assert_error %(
      enum Foo
        One
        Two
        Three
      end

      enum Foo2
        One
        Two
        Three
      end

      def foo(x : Foo)
        x
      end

      def foo(x : Foo2)
        x
      end

      foo(:one)
      ),
      "ambiguous"
  end

  it "casts Int32 to Int64 in ivar assignment" do
    assert_type(%(
      class Foo
        @x : Int64

        def initialize
          @x = 10
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int64 }
  end

  it "casts Symbol to Enum in ivar assignment" do
    assert_type(%(
      enum E
        One
        Two
        Three
      end

      class Foo
        @x : E

        def initialize
          @x = :two
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { types["E"] }
  end

  it "casts Int32 to Int64 in cvar assignment" do
    assert_type(%(
      class Foo
        @@x : Int64 = 0_i64

        def self.x
          @@x = 10
          @@x
        end
      end

      Foo.x
      )) { int64 }
  end

  it "casts Int32 to Int64 in lvar assignment" do
    assert_type(%(
      x : Int64
      x = 123
      x
      )) { int64 }
  end

  it "casts Int32 to Int64 in ivar type declaration" do
    assert_type(%(
      class Foo
        @x : Int64 = 10

        def x
          @x
        end
      end

      Foo.new.x
      )) { int64 }
  end

  it "casts Symbol to Enum in ivar type declaration" do
    assert_type(%(
      enum Color
        Red
        Green
        Blue
      end

      class Foo
        @x : Color = :red

        def x
          @x
        end
      end

      Foo.new.x
      )) { types["Color"] }
  end

  it "casts Int32 to Int64 in cvar type declaration" do
    assert_type(%(
      class Foo
        @@x : Int64 = 10

        def self.x
          @@x
        end
      end

      Foo.x
      )) { int64 }
  end

  it "casts Symbol to Enum in cvar type declaration" do
    assert_type(%(
      enum Color
        Red
        Green
        Blue
      end

      class Foo
        @@x : Color = :red

        def self.x
          @@x
        end
      end

      Foo.x
      )) { types["Color"] }
  end

  it "casts Int32 -> Int64 in arg restriction" do
    assert_type(%(
      def foo(x : Int64 = 0)
        x
      end

      foo
      )) { int64 }
  end

  it "casts Int32 to Int64 in ivar type declaration in generic" do
    assert_type(%(
      class Foo(T)
        @x : T = 10

        def x
          @x
        end
      end

      Foo(Int64).new.x
      )) { int64 }
  end
end
