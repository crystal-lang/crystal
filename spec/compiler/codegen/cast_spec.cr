require "../../spec_helper"

describe "Code gen: cast" do
  it "allows casting object to pointer and back" do
    run(%(
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
      )).to_i.should eq(1)
  end

  it "casts from int to int" do
    run(%(
      require "prelude"

      a = 1
      b = a.as(Int32)
      b.abs
      )).to_i.should eq(1)
  end

  it "casts from union to single type" do
    run(%(
      require "prelude"

      a = 1 || 'a'
      b = a.as(Int32)
      b.abs
      )).to_i.should eq(1)
  end

  it "casts from union to single type raises TypeCastError" do
    run(%(
      require "prelude"

      a = 1 || 'a'
      begin
        a.as(Char)
        false
      rescue ex
        ex.message.not_nil!.includes?("Cast from Int32 to Char failed") && (ex.class == TypeCastError)
      end
      )).to_b.should be_true
  end

  it "casts from union to another union" do
    run(%(
      require "prelude"

      a = 1 || 1.5 || 'a'
      b = a.as(Int32 | Float64)
      b.abs.to_i
      )).to_i.should eq(1)
  end

  it "casts from union to another union raises TypeCastError" do
    run(%(
      require "prelude"

      a = 1 || 1.5 || 'a'
      begin
        a.as(Float64 | Char)
        false
      rescue ex
        ex.message.not_nil!.includes?("Cast from Int32 to (Char | Float64) failed") && (ex.class == TypeCastError)
      end
      )).to_b.should be_true
  end

  it "casts from virtual to single type" do
    run(%(
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
      )).to_i.should eq(1)
  end

  it "casts from virtual to single type raises TypeCastError" do
    run(%(
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
      )).to_b.should be_true
  end

  it "casts from pointer to pointer" do
    run(%(
      require "prelude"

      a = 1_i64
      pointerof(a).as(Int32*).value
      )).to_i.should eq(1)
  end

  it "casts to module" do
    run(%(
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
      )).to_i.should eq(2)
  end

  it "casts from nilable to nil" do
    run(%(
      require "prelude"

      a = 1 == 2 ? Reference.new : nil
      c = a.as(Nil)
      c == nil
      )).to_b.should be_true
  end

  it "casts from nilable to nil raises TypeCastError" do
    run(%(
      require "prelude"

      a = 1 == 1 ? Reference.new : nil
      begin
        a.as(Nil)
        false
      rescue ex
        ex.message.not_nil!.includes?("Cast from Reference to Nil failed") && (ex.class == TypeCastError)
      end
      )).to_b.should be_true
  end

  it "casts to base class making it virtual" do
    run(%(
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
      )).to_i.should eq(1)
  end

  it "casts to bigger union" do
    run(%(
      x = 1.5.as(Int32 | Float64)
      x.to_i!
      )).to_i.should eq(1)
  end

  it "allows casting nil to Void*" do
    run(%(
      nil.as(Void*).address
      )).to_i.should eq(0)
  end

  it "allows casting nilable type to Void* (1)" do
    run(%(
      a = 1 == 1 ? Reference.new : nil
      a.as(Void*).address
      )).to_i.should_not eq(0)
  end

  it "allows casting nilable type to Void* (2)" do
    run(%(
      a = 1 == 2 ? Reference.new : nil
      a.as(Void*).address
      )).to_i.should eq(0)
  end

  it "allows casting nilable type to Void* (3)" do
    run(%(
      class Foo
      end
      a = 1 == 1 ? Reference.new : (1 == 2 ? Foo.new : nil)
      a.as(Void*).address
      )).to_i.should_not eq(0)
  end

  it "casts (bug)" do
    run(%(
      require "prelude"
      (1 || 1.1).as(Int32)
      123
      )).to_i.should eq(123)
  end

  it "can cast from Void* to virtual type (#3014)" do
    run(%(
      abstract class Foo
        abstract def hi
      end

      class Bar < Foo
        def hi
          42
        end
      end

      Bar.new.as(Void*).as(Foo).hi
      )).to_i.should eq(42)
  end

  it "upcasts from non-generic to generic" do
    run(%(
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
      )).to_i.should eq(2)
  end

  it "upcasts type to virtual (#3304)" do
    run(%(
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
      )).to_i.should eq(1)
  end

  it "upcasts type to virtual (2) (#3304)" do
    run(%(
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
      )).to_i.should eq(1)
  end

  it "casts with block var that changes type (#3341)" do
    codegen(%(
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
      ))
  end

  it "casts between union types, where union has a tuple type (#3377)" do
    codegen(%(
      require "prelude"

      v = 1 || true || 1.0
      (v || {v}).as(Bool | Float64)
      ))
  end

  it "codegens class method when type id is available but not a virtual type (#3490)" do
    run(%(
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
      )).to_string.should eq("A")
  end

  it "casts from nilable type to virtual type (#3512)" do
    run(%(
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
      )).to_i.should eq(1)
  end

  it "can cast to metaclass (#11121)" do
    run(%(
      class A
      end

      class B < A
      end

      A.as(A.class)
      ))
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
