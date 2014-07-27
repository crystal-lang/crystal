#!/usr/bin/env bin/crystal --run
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
        ex.message == "type cast exception"
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

  pending "casts from union to another union raises" do
    run(%(
      require "prelude"

      a = 1 || 1.5 || 'a'
      begin
        a as Float64 | Char
        false
      rescue ex
        ex.message == "type cast exception"
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
        ex.message == "type cast exception"
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

  it "casts pointer to string (1)" do
    run(%(
      require "prelude"

      c = Pointer(UInt8).malloc(11)
      (c as Int32*).value = "".crystal_type_id
      ((c as Int32*) + 1).value = 2
      c[8] = 'h'.ord.to_u8
      c[9] = 'i'.ord.to_u8
      c[10] = '\0'.ord.to_u8
      str = c as String
      str.length
      )).to_i.should eq(2)
  end

  it "casts pointer to string (2)" do
    run(%(
      require "prelude"

      c = Pointer(UInt8).malloc(11)
      (c as Int32*).value = "".crystal_type_id
      ((c as Int32*) + 1).value = 2
      c[8] = 'h'.ord.to_u8
      c[9] = 'i'.ord.to_u8
      c[10] = '\0'.ord.to_u8
      c as String
      )).to_string.should eq("hi")
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
        ex.message == "type cast exception"
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
        ex.message == "type cast exception"
      end
      )).to_b.should be_true
  end
end
