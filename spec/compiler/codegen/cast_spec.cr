require "../../spec_helper"

describe "Code gen: cast" do
  it "allows casting object to pointer and back" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      f = Foo.new(1)
      p = f.as(Void*)
      f = p.as(Foo)
      f.x
      CRYSTAL
  end

  it "casts from int to int" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      a = 1
      b = a.as(Int32)
      b.abs
      CRYSTAL
  end

  it "casts from union to single type" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      a = 1 || 'a'
      b = a.as(Int32)
      b.abs
      CRYSTAL
  end

  it "casts from union to single type raises TypeCastError" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"

      a = 1 || 'a'
      begin
        a.as(Char)
        false
      rescue ex
        ex.message.not_nil!.includes?("Cast from Int32 to Char failed") && (ex.class == TypeCastError)
      end
      CRYSTAL
  end

  it "casts from union to another union" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      a = 1 || 1.5 || 'a'
      b = a.as(Int32 | Float64)
      b.abs.to_i
      CRYSTAL
  end

  it "casts from union to another union raises TypeCastError" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"

      a = 1 || 1.5 || 'a'
      begin
        a.as(Float64 | Char)
        false
      rescue ex
        ex.message.not_nil!.includes?("Cast from Int32 to (Char | Float64) failed") && (ex.class == TypeCastError)
      end
      CRYSTAL
  end

  it "upcasts from union to union with different alignment" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      a = 1 || 2_i64
      a.as(Int32 | Int64 | Int128)
      CRYSTAL
  end

  it "downcasts from union to union with different alignment" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      a = 1 || 2_i64 || 3_i128
      a.as(Int32 | Int64)
      CRYSTAL
  end

  it "sidecasts from union to union with different alignment" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      a = 1 || 2_i64
      a.as(Int32 | Int128)
      CRYSTAL
  end

  it "doesn't corrupt stack when downcasting union to union with different alignment (#14285)" do
    run(<<-CRYSTAL).to_b.should be_true
      struct Time2
        def initialize(@seconds : Int64)
          @nanoseconds = uninitialized UInt32[3]
        end

        def <(other : Time2) : Bool
          @seconds < other.@seconds
        end
      end

      class Constraints::Range
        def initialize(@min : Int128 | Time2 | Nil)
        end
      end

      def validate(value : Time2, constraint) : Bool
        min = constraint.@min
        if min.is_a?(Time2?)
          if min
            if value < min
              return false
            end
          end
        end
        true
      end

      value = Time2.new(123)
      constraint = Constraints::Range.new(Time2.new(45))
      validate(value, constraint)
      CRYSTAL
  end

  it "casts from virtual to single type" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      class CastSpecFoo
      end

      class CastSpecBar < CastSpecFoo
        def bar
          1
        end
      end

      class CastSpecBaz < CastSpecBar
      end

      a = CastSpecBar.new || CastSpecFoo.new || CastSpecBaz.new
      b = a.as(CastSpecBar)
      b.bar
      CRYSTAL
  end

  it "casts from virtual to single type raises TypeCastError" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"

      class CastSpecFoo
      end

      class CastSpecBar < CastSpecFoo
        def bar
          1
        end
      end

      class CastSpecBaz < CastSpecBar
      end

      a = CastSpecBar.new || CastSpecFoo.new || CastSpecBaz.new
      begin
        a.as(CastSpecBaz)
        false
      rescue ex
        ex.message.not_nil!.includes?("Cast from CastSpecBar to CastSpecBaz failed") && (ex.class == TypeCastError)
      end
      CRYSTAL
  end

  it "casts from pointer to pointer" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      a = 1_i64
      pointerof(a).as(Int32*).value
      CRYSTAL
  end

  it "casts to module" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "prelude"

      module CastSpecMoo
        def moo
          2
        end
      end

      class CastSpecFoo
      end

      class CastSpecBar < CastSpecFoo
        include CastSpecMoo

        def bar
          1
        end
      end

      class CastSpecBaz < CastSpecBar
      end

      class CastSpecBan < CastSpecFoo
        include CastSpecMoo
      end

      a = CastSpecBar.new || CastSpecFoo.new || CastSpecBaz.new || CastSpecBan.new
      m = a.as(CastSpecMoo)
      m.moo
      CRYSTAL
  end

  it "casts from nilable to nil" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"

      a = 1 == 2 ? Reference.new : nil
      c = a.as(Nil)
      c == nil
      CRYSTAL
  end

  it "casts from nilable to nil raises TypeCastError" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"

      a = 1 == 1 ? Reference.new : nil
      begin
        a.as(Nil)
        false
      rescue ex
        ex.message.not_nil!.includes?("Cast from Reference to Nil failed") && (ex.class == TypeCastError)
      end
      CRYSTAL
  end

  it "casts to base class making it virtual" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          1.5
        end
      end

      bar = Bar.new
      x = bar.as(Foo).foo
      x.to_i!
      CRYSTAL
  end

  it "casts to bigger union" do
    run(<<-CRYSTAL).to_i.should eq(1)
      x = 1.5.as(Int32 | Float64)
      x.to_i!
      CRYSTAL
  end

  it "allows casting nil to Void*" do
    run(<<-CRYSTAL).to_i.should eq(0)
      nil.as(Void*).address
      CRYSTAL
  end

  it "allows casting nilable type to Void* (1)" do
    run(<<-CRYSTAL).to_i.should_not eq(0)
      a = 1 == 1 ? Reference.new : nil
      a.as(Void*).address
      CRYSTAL
  end

  it "allows casting nilable type to Void* (2)" do
    run(<<-CRYSTAL).to_i.should eq(0)
      a = 1 == 2 ? Reference.new : nil
      a.as(Void*).address
      CRYSTAL
  end

  it "allows casting nilable type to Void* (3)" do
    run(<<-CRYSTAL).to_i.should_not eq(0)
      class Foo
      end
      a = 1 == 1 ? Reference.new : (1 == 2 ? Foo.new : nil)
      a.as(Void*).address
      CRYSTAL
  end

  it "casts (bug)" do
    run(<<-CRYSTAL).to_i.should eq(123)
      require "prelude"
      (1 || 1.1).as(Int32)
      123
      CRYSTAL
  end

  it "can cast from Void* to virtual type (#3014)" do
    run(<<-CRYSTAL).to_i.should eq(42)
      abstract class Foo
        abstract def hi
      end

      class Bar < Foo
        def hi
          42
        end
      end

      Bar.new.as(Void*).as(Foo).hi
      CRYSTAL
  end

  it "upcasts from non-generic to generic" do
    run(<<-CRYSTAL).to_i.should eq(2)
      class Foo(T)
        def foo
          1
        end
      end

      class Bar < Foo(Int32)
        def foo
          2
        end
      end

      Bar.new.as(Foo(Int32)).foo
      CRYSTAL
  end

  it "upcasts type to virtual (#3304)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          2
        end
      end

      Foo.new.as(Foo).foo
      CRYSTAL
  end

  it "upcasts type to virtual (2) (#3304)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          2
        end
      end

      class Gen(T)
        def self.cast(x)
          x.as(T)
        end
      end

      Gen(Foo).cast(Foo.new).foo
      CRYSTAL
  end

  it "casts with block var that changes type (#3341)" do
    codegen(<<-CRYSTAL)
      require "prelude"

      class Object
        def try
          yield self
        end
      end

      class Foo
      end

      x = Foo.new.as(Int32 | Foo)
      x.try &.as(Foo)
      CRYSTAL
  end

  it "casts between union types, where union has a tuple type (#3377)" do
    codegen(<<-CRYSTAL)
      require "prelude"

      v = 1 || true || 1.0
      (v || {v}).as(Bool | Float64)
      CRYSTAL
  end

  it "codegens class method when type id is available but not a virtual type (#3490)" do
    run(<<-CRYSTAL).to_string.should eq("A")
      class Class
        def name : String
          {{ @type.name.stringify }}
        end
      end

      class Super
      end

      module Mixin
      end

      class A < Super
        include Mixin
      end

      class B < Super
        include Mixin
      end

      a = A.new.as(Super)
      if a.is_a?(Mixin)
        a.class.name
      else
        "Nope"
      end
      CRYSTAL
  end

  it "casts from nilable type to virtual type (#3512)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          2
        end
      end

      foo = 1 == 2 ? nil : Foo.new
      x = foo.as(Foo)
      x.foo
      CRYSTAL
  end

  it "can cast to metaclass (#11121)" do
    run(<<-CRYSTAL)
      class A
      end

      class B < A
      end

      A.as(A.class)
      CRYSTAL
  end

  it "cast virtual metaclass type to nilable virtual instance type (#12628)" do
    run(<<-CRYSTAL).to_b.should be_true
      abstract struct Base
      end

      struct Impl < Base
      end

      Base.as(Base | Base.class).as?(Base | Impl).nil?
      CRYSTAL
  end
end
