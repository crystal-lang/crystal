require "../../spec_helper"

describe "Code gen: cast" do
  it "allows casting object to pointer and back" do
    run(%(
      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      f = Foo.new(1)
      p = f as Void*
      f = p as Foo
      f.x
      )).to_i.should eq(1)
  end

  it "casts from int to int" do
    run(%(
      require "prelude"

      a = 1
      b = a as Int32
      b.abs
      )).to_i.should eq(1)
  end

  it "casts from union to single type" do
    run(%(
      require "prelude"

      a = 1 || 'a'
      b = a as Int32
      b.abs
      )).to_i.should eq(1)
  end

  it "casts from union to single type raises" do
    run(%(
      require "prelude"

      a = 1 || 'a'
      begin
        a as Char
        false
      rescue ex
        ex.message == "cast to Char failed"
      end
      )).to_b.should be_true
  end

  it "casts from union to another union" do
    run(%(
      require "prelude"

      a = 1 || 1.5 || 'a'
      b = a as Int32 | Float64
      b.abs.to_i
      )).to_i.should eq(1)
  end

  it "casts from union to another union raises" do
    run(%(
      require "prelude"

      a = 1 || 1.5 || 'a'
      begin
        a as Float64 | Char
        false
      rescue ex
        ex.message == "cast to (Float64 | Char) failed"
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
      b = a as CastSpecBar
      b.bar
      )).to_i.should eq(1)
  end

  it "casts from virtual to single type raises" do
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
        a as CastSpecBaz
        false
      rescue ex
        ex.message == "cast to CastSpecBaz failed"
      end
      )).to_b.should be_true
  end

  it "casts from pointer to pointer" do
    run(%(
      require "prelude"

      a = 1_i64
      (pointerof(a) as Int32*).value
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
      m = a as CastSpecMoo
      m.moo
      )).to_i.should eq(2)
  end

  it "casts from nilable to nil" do
    run(%(
      require "prelude"

      a = 1 == 2 ? Reference.new : nil
      c = a as Nil
      c == nil
      )).to_b.should be_true
  end

  it "casts from nilable to nil raises" do
    run(%(
      require "prelude"

      a = 1 == 1 ? Reference.new : nil
      begin
        a as Nil
        false
      rescue ex
        ex.message.includes? "cast to Nil failed"
      end
      )).to_b.should be_true
  end

  it "casts from nilable to reference" do
    run(%(
      require "prelude"

      a = 1 == 1 ? Reference.new : nil
      c = a as Reference
      c == nil
      )).to_b.should be_false
  end

  it "casts from nilable to reference raises" do
    run(%(
      require "prelude"

      a = 1 == 2 ? Reference.new : nil
      begin
        a as Reference
        false
      rescue ex
        ex.message == "cast to Reference failed"
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
      x = (bar as Foo).foo
      x.to_i
      )).to_i.should eq(1)
  end

  it "casts to bigger union" do
    run(%(
      x = 1.5 as Int32 | Float64
      x.to_i
      )).to_i.should eq(1)
  end
end
