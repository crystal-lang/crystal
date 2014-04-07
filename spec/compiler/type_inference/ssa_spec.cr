#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

include Crystal

describe "Type inference: ssa" do
  it "types a redefined variable" do
    assert_type("
      a = 1
      a = 'a'
      a
      ") { char }
  end

  it "types a var inside an if without previous definition" do
    assert_type("
      if 1 == 1
        a = 1
      else
        a = 'a'
      end
      a
      ") { union_of(int32, char) }
  end

  it "types a var inside an if with previous definition" do
    assert_type(%(
      a = "hello"
      if 1 == 1
        a = 1
      else
        a = 'a'
      end
      a
      )) { union_of(int32, char) }
  end

  it "types a var inside an if without change in then" do
    assert_type(%(
      a = 1
      if 1 == 1
      else
        a = 'a'
      end
      a
      )) { union_of(int32, char) }
  end

  it "types a var inside an if without change in else" do
    assert_type(%(
      a = 1
      if 1 == 1
        a = 'a'
      else
      end
      a
      )) { union_of(int32, char) }
  end

  it "types a var inside an if without definition in else" do
    assert_type(%(
      if 1 == 1
        a = 'a'
      else
      end
      a
      )) { |mod| union_of(mod.nil, mod.char) }
  end

  it "types a var inside an if without definition in then" do
    assert_type(%(
      if 1 == 1
      else
        a = 'a'
      end
      a
      )) { |mod| union_of(mod.nil, mod.char) }
  end

  it "types a var with an if but without change" do
    assert_type(%(
      a = 1
      if 1 == 1
      else
      end
      a
      )) { int32 }
  end

  it "types a var that is re-assigned in a block" do
    assert_type(%(
      def foo
        yield
      end

      a = 1
      foo do
        a = 'a'
      end
      a
      )) { union_of(int32, char) }
  end

  it "types a var that is re-assigned in a while" do
    assert_type(%(
      a = 1
      while 1 == 2
        a = 'a'
      end
      a
      )) { union_of(int32, char) }
  end

  it "types a var that is declared in a while" do
    assert_type(%(
      while 1 == 2
        a = 1
      end
      a
      )) { |mod| union_of(mod.nil, mod.int32) }
  end

  it "types a var that is re-assigned in a while condition" do
    assert_type(%(
      a = 1
      while a = 'a'
        a = "hello"
      end
      a
      )) { char }
  end

  it "types a var that is declared in a while condition" do
    assert_type(%(
      while a = 'a'
        a = "hello"
      end
      a
      )) { char }
  end

  it "types a var that is declared in a while with out" do
    assert_type(%(
      lib C
        fun foo(x : Int32*)
      end

      a = 'a'
      while 1 == 2
        C.foo(out x)
        a = x
      end
      a
      )) { union_of(char, int32) }
  end

  it "types a var after begin rescue as having all possible types in begin" do
    assert_type(%(
      a = 1.5
      begin
        a = 2
        a = 'a'
        a = "hello"
      ensure
      end
      a
      )) { union_of [float64, int32, char, string] of Type }
  end

  it "types a var after begin rescue as having all possible types in begin and rescue" do
    assert_type(%(
      a = 1.5
      begin
        a = 2
        a = 'a'
        a = "hello"
      rescue ex
        a = false
      end
      a
      )) { union_of [float64, int32, char, string, bool] of Type }
  end

  it "types a var after begin rescue as having all possible types in begin and rescue (2)" do
    assert_type(%(
      b = 2
      begin
        a = 2
        a = 'a'
        a = "hello"
      rescue ex
        b = a
      end
      b
      )) { union_of [int32, char, string] of Type }
  end
end
