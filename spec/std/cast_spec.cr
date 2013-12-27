#!/usr/bin/env bin/crystal --run
require "spec"

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

describe "Cast" do
  it "casts from int to int" do
    a = 1
    b = a as Int32
    b.abs.should eq(1)
  end

  it "casts from union to single type" do
    a = 1 || 'a'
    b = a as Int32
    b.abs.should eq(1)
  end

  it "casts from union to single type raises" do
    a = 1 || 'a'
    begin
      a as Char
      fail "expected cast to raise"
    rescue ex
      ex.message.should eq("type cast exception")
    end
  end

  it "casts from union to another union" do
    a = 1 || 1.5 || 'a'
    b = a as Int32 | Float64
    b.abs.should eq(1)
  end

  pending "casts from union to another union raises" do
    a = 1 || 1.5 || 'a'
    begin
      a as Float64 | Char
      fail "expected cast to raise"
    rescue ex
      ex.message.should eq("type cast exception")
    end
  end

  it "casts from hierarchy to single type" do
    a = CastSpecBar.new || CastSpecFoo.new || CastSpecBaz.new
    b = a as CastSpecBar
    b.bar.should eq(1)
  end

  it "casts from hierarchy to single type raises" do
    a = CastSpecBar.new || CastSpecFoo.new || CastSpecBaz.new
    begin
      a as CastSpecBaz
      fail "expected cast to raise"
    rescue ex
      ex.message.should eq("type cast exception")
    end
  end

  it "casts from pointer to pointer" do
    a = 1_i64
    (pointerof(a) as Int32*).value.should eq(1)
  end

  it "casts pointer to string" do
    c = Pointer(Char).malloc(7)
    (c as Int32*).value = 2
    c[4] = 'h'
    c[5] = 'i'
    c[6] = '\0'
    str = c as String
    str.length.should eq(2)
    str.should eq("hi")
  end

  it "casts to module" do
    a = CastSpecBar.new || CastSpecFoo.new || CastSpecBaz.new || CastSpecBan.new
    m = a as CastSpecMoo
    m.moo.should eq(2)
  end
end
