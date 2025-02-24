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
      "expected argument #1 to 'foo' to be Int32, not Int64"
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

  it "casts literal integer in private top-level method (#7016)" do
    assert_type(%(
      private def foo(x : Int64)
        x
      end

      foo(12345)
      )) { int64 }
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

      def foo(x : Int16)
        x
      end

      foo(1)
      ),
      "ambiguous call, implicit cast of 1 matches all of Int8, UInt8, Int16"
  end

  it "says ambiguous call for integer (2)" do
    assert_error %(
      def foo(x : Int8 | UInt8)
        x
      end

      foo(1)
      ),
      "ambiguous call, implicit cast of 1 matches all of Int8, UInt8"
  end

  it "says ambiguous call for integer on alias (#6620)" do
    assert_error %(
      alias A = Int8 | UInt8

      def foo(x : A)
        x
      end

      foo(1)
      ),
      "ambiguous call, implicit cast of 1 matches all of Int8, UInt8"
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
      "expected argument #1 to 'foo' to match a member of enum Foo"
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
      "ambiguous call, implicit cast of :one matches all of Foo, Foo2"
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

  it "can match multiple times with the same argument type (#7578)" do
    assert_type(%(
      def foo(unused, foo : Int64)
        unused
      end

      def foo(foo : Int64)
        foo
      end

      foo(foo: 1)
      )) { int64 }
  end

  it "doesn't say 'ambiguous call' when there's an exact match for integer (#6601)" do
    assert_error %(
      class Zed
        def +(other : Char)
        end
      end

      a = 1 || Zed.new
      a + 2
      ),
      "expected argument #1 to 'Zed#+' to be Char, not Int32",
      inject_primitives: true
  end

  it "doesn't say 'ambiguous call' when there's an exact match for symbol (#6601)" do
    assert_error %(
      enum Color1
        Red
      end

      enum Color2
        Red
      end

      struct Int
        def +(x : Color1)
        end

        def +(x : Color2)
        end
      end

      class Zed
        def +(other : Char)
        end
      end

      a = 1 || Zed.new
      a + :red
      ),
      "expected argument #1 to 'Zed#+' to be Char, not Symbol"
  end

  it "can use automatic cast with `with ... yield` (#7736)" do
    assert_type(%(
      def foo
        with 1 yield
      end

      struct Int32
        def bar(x : Int64)
          x
        end
      end

      foo do
        bar(1)
      end
      )) { int64 }
  end

  it "doesn't do multidispatch if an overload matches exactly (#8217)" do
    assert_type(%(
      def foo(x : Int64)
        x
      end

      def foo(*xs : Int64)
        xs
      end

      foo(1)
      )) { int64 }
  end

  it "autocasts first argument and second matches without autocast" do
    assert_type(%(
      def fill(x : Float64, y : Int)
        x
      end

      fill(0, 0)
      )) { float64 }
  end

  it "can autocast to union in default value" do
    assert_type(%(
      def fill(x : Int64 | String = 1)
        x
      end

      fill()
      )) { int64 }
  end

  it "can autocast to alias in default value" do
    assert_type(%(
      alias X = Int64 | String

      def fill(x : X = 1)
        x
      end

      fill()
      )) { int64 }
  end

  it "can autocast to union in default value (symbol and int)" do
    assert_type(%(
      enum Color
        Red
      end

      def fill(x : Int64 | Color = :red)
        x
      end

      fill()
      )) { types["Color"] }
  end

  it "can autocast to union in default value (multiple enums)" do
    assert_type(%(
      enum Color
        Red
      end

      enum AnotherColor
        Blue
      end

      def fill(x : Color | AnotherColor = :blue)
        x
      end

      fill()
      )) { types["AnotherColor"] }
  end

  it "doesn't do multidispatch if an overload matches exactly (#8217)" do
    assert_type(%(
      abstract class Foo
      end

      class Bar < Foo
        def foo(x : Int64)
          x
        end

        def foo(*xs : Int64)
          xs
        end
      end

      class Baz < Foo
        def foo(x : Int64)
          x
        end

        def foo(*xs : Int64)
          xs
        end
      end

      Baz.new.as(Foo).foo(1)
    )) { int64 }
  end

  it "casts integer variable to larger type (#9565)" do
    assert_type(%(
      def foo(x : Int64)
        x
      end

      x = 1_i32
      foo(x)
      )) { int64 }
  end

  it "casts integer variable to larger type (Int64 to Int128) (#9565)" do
    assert_type(%(
      def foo(x : Int128)
        x
      end

      x = 1_i64
      foo(x)
      )) { int128 }
  end

  it "casts integer expression to larger type (#9565)" do
    assert_type(%(
      def foo(x : Int64)
        x
      end

      def bar
        1_i32
      end

      foo(bar)
      )) { int64 }
  end

  it "says ambiguous call for integer var to larger type (#9565)" do
    assert_error %(
      def foo(x : Int32)
        x
      end

      def foo(x : Int64)
        x
      end

      x = 1_u8
      foo(x)
      ),
      "ambiguous call, implicit cast of UInt8 matches all of Int32, Int64"
  end

  it "says ambiguous call for integer var to union type (#9565)" do
    assert_error %(
      def foo(x : Int32 | UInt32)
        x
      end

      x = 1_u8
      foo(x)
      ),
      "ambiguous call, implicit cast of UInt8 matches all of Int32, UInt32"
  end

  it "can't cast integer to another type when it doesn't fit (#9565)" do
    assert_error %(
      def foo(x : Int32)
        x
      end

      x = 1_i64
      foo(x)
      ),
      "expected argument #1 to 'foo' to be Int32, not Int64"
  end

  it "doesn't cast integer variable to larger type (not #9565)" do
    assert_error %(
      def foo(x : Int64)
        x
      end

      x = 1_i32
      foo(x)
      ),
      "expected argument #1 to 'foo' to be Int64, not Int32",
      flags: "no_number_autocast"
  end

  it "doesn't autocast number on union (#8655)" do
    assert_type(%(
      def foo(x : UInt8 | Int32, y : Float64)
        x
      end

      foo(255, 60)
      )) { int32 }
  end

  it "says ambiguous call on union (#8655)" do
    assert_error %(
      def foo(x : UInt64 | Int64, y : Float64)
        x
      end

      foo(255, 60)
      ),
      "ambiguous call, implicit cast of 255 matches all of UInt64, Int64"
  end

  it "autocasts integer variable to float type (#9565)" do
    assert_type(%(
      def foo(x : Float64)
        x
      end

      x = 1_i32
      foo(x)
      )) { float64 }
  end

  it "autocasts float32 variable to float64 type (#9565)" do
    assert_type(%(
      def foo(x : Float64)
        x
      end

      x = 1.0_f32
      foo(x)
      )) { float64 }
  end

  it "autocasts nested type from non-nested type (#10315)" do
    assert_no_errors(%(
      module Moo
        enum Color
          Red
        end

        abstract class Foo
          def initialize(color : Color = :red)
          end
        end
      end

      class Bar < Moo::Foo
      end

      Bar.new
      ))
  end

  it "errors when autocast default value doesn't match enum member" do
    assert_error <<-CRYSTAL,
      enum Foo
        FOO
      end

      def foo(foo : Foo = :bar)
      end

      foo
      CRYSTAL
      "can't autocast :bar to Foo: no matching enum member"
  end
end
