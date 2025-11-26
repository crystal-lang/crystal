require "../../spec_helper"

describe "Code gen: automatic cast" do
  it "casts literal integer (Int32 -> Int64)" do
    run(<<-CRYSTAL).to_i.should eq(12345)
      def foo(x : Int64)
        x
      end

      foo(12345)
      CRYSTAL
  end

  it "casts literal integer (Int64 -> Int32, ok)" do
    run(<<-CRYSTAL).to_i.should eq(2147483647)
      def foo(x : Int32)
        x
      end

      foo(2147483647_i64)
      CRYSTAL
  end

  it "casts literal integer (Int32 -> Float32)" do
    run(<<-CRYSTAL).to_i.should eq(12345)
      def foo(x : Float32)
        x
      end

      foo(12345).to_i!
      CRYSTAL
  end

  it "casts literal integer (Int32 -> Float64)" do
    run(<<-CRYSTAL).to_i.should eq(12345)
      def foo(x : Float64)
        x
      end

      foo(12345).to_i!
      CRYSTAL
  end

  it "casts literal float (Float32 -> Float64)" do
    run(<<-CRYSTAL).to_i.should eq(12345)
      def foo(x : Float64)
        x
      end

      foo(12345.0_f32).to_i!
      CRYSTAL
  end

  it "casts literal float (Float64 -> Float32)" do
    run(<<-CRYSTAL).to_i.should eq(12345)
      def foo(x : Float32)
        x
      end

      foo(12345.0).to_i!
      CRYSTAL
  end

  it "casts symbol literal to enum" do
    run(<<-CRYSTAL).to_i.should eq(2)
      :four

      enum Foo
        One
        Two
        Three
      end

      def foo(x : Foo)
        x
      end

      foo(:three)
      CRYSTAL
  end

  it "casts Int32 to Int64 in ivar assignment" do
    run(<<-CRYSTAL).to_i.should eq(10)
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
      CRYSTAL
  end

  it "casts Symbol to Enum in ivar assignment" do
    run(<<-CRYSTAL).to_i.should eq(2)
      enum E
        One
        Two
        Three
      end

      class Foo
        @x : E

        def initialize
          @x = :three
        end

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "casts Int32 to Int64 in cvar assignment" do
    run(<<-CRYSTAL).to_i.should eq(10)
      class Foo
        @@x : Int64 = 0_i64

        def self.x
          @@x = 10
          @@x
        end
      end

      Foo.x
      CRYSTAL
  end

  it "casts Int32 to Int64 in lvar assignment" do
    run(<<-CRYSTAL).to_i.should eq(123)
      x : Int64
      x = 123
      x
      CRYSTAL
  end

  it "casts Int32 to Int64 in ivar type declaration" do
    run(<<-CRYSTAL).to_i.should eq(10)
      class Foo
        @x : Int64 = 10

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "casts Symbol to Enum in ivar type declaration" do
    run(<<-CRYSTAL).to_i.should eq(2)
      enum Color
        Red
        Green
        Blue
      end

      class Foo
        @x : Color = :blue

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "casts Int32 to Int64 in cvar type declaration" do
    run(<<-CRYSTAL).to_i.should eq(10)
      class Foo
        @@x : Int64 = 10

        def self.x
          @@x
        end
      end

      Foo.x
      CRYSTAL
  end

  it "casts Int32 -> Int64 in arg restriction" do
    run(<<-CRYSTAL).to_i.should eq(123)
      def foo(x : Int64 = 123)
        x
      end

      foo
      CRYSTAL
  end

  it "casts Int32 to Int64 in ivar type declaration in generic" do
    run(<<-CRYSTAL).to_i.should eq(10)
      class Foo(T)
        @x : T = 10

        def x
          @x
        end
      end

      Foo(Int64).new.x
      CRYSTAL
  end

  it "does multidispatch with automatic casting (1) (#8217)" do
    run(<<-CRYSTAL).to_i.should eq(10)
      def foo(mode : Int64, x : Int32)
        10
      end
      def foo(mode : Int64, x : String)
        20
      end
      foo(1, 1 || "a")
      CRYSTAL
  end

  it "does multidispatch with automatic casting (2) (#8217)" do
    run(<<-CRYSTAL).to_i.should eq(20)
      def foo(mode : Int64, x : Int32)
        10
      end
      def foo(mode : Int64, x : String)
        20
      end
      foo(1, "a" || 1)
      CRYSTAL
  end

  it "does multidispatch with automatic casting (3)" do
    run(<<-CRYSTAL).to_i.should eq(2)
      abstract class Foo
      end

      class Bar < Foo
        def foo(x : UInt8)
          2
        end
      end

      class Baz < Foo
        def foo(x : UInt8)
          3
        end
      end

      Bar.new.as(Foo).foo(1)
      CRYSTAL
  end

  it "doesn't autocast number on union (#8655)" do
    run(<<-CRYSTAL).to_i.should eq(255)
      def foo(x : UInt8 | Int32, y : Float64)
        x
      end

      foo(255, 60)
      CRYSTAL
  end

  it "casts integer variable to larger type (#9565)" do
    run(<<-CRYSTAL).to_i64.should eq(123)
      def foo(x : Int64)
        x
      end

      x = 123
      foo(x)
      CRYSTAL
  end
end
