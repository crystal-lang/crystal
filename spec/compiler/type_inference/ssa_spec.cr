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
end
