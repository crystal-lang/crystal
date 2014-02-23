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
    c = Pointer(UInt8).malloc(11)
    (c as Int32*).value = "".crystal_type_id
    ((c as Int32*) + 1).value = 2
    c[8] = 'h'.ord.to_u8
    c[9] = 'i'.ord.to_u8
    c[10] = '\0'.ord.to_u8
    str = c as String
    str.length.should eq(2)
    str.should eq("hi")
  end

  it "casts to module" do
    a = CastSpecBar.new || CastSpecFoo.new || CastSpecBaz.new || CastSpecBan.new
    m = a as CastSpecMoo
    m.moo.should eq(2)
  end

  it "casts from nilable to nil" do
    a = 1 == 2 ? Reference.new : nil
    c = a as Nil
    c.should be_nil
  end

  it "casts from nilable to nil raises" do
    begin
      a = 1 == 1 ? Reference.new : nil
      a as Nil
    rescue ex
      ex.message.should eq("type cast exception")
    end
  end

  it "casts from nilable to reference" do
    a = 1 == 1 ? Reference.new : nil
    c = a as Reference
    c.should_not be_nil
  end

  it "casts from nilable to reference raises" do
    begin
      a = 1 == 2 ? Reference.new : nil
      a as Reference
    rescue ex
      ex.message.should eq("type cast exception")
    end
  end
end
