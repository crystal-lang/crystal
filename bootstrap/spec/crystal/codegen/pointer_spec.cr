#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

describe "Code gen: pointer" do
  it "get pointer and value of it" do
    run("a = 1; b = a.ptr; b.value").to_i.should eq(1)
  end

  it "get pointer of instance var" do
    run("
      class Foo
        def initialize(value)
          @value = value
        end

        def value_ptr
          @value.ptr
        end
      end

      foo = Foo.new(10)
      value_ptr = foo.value_ptr
      value_ptr.value
      ").to_i.should eq(10)
  end

  it "set pointer value" do
    run("a = 1; b = a.ptr; b.value = 2; a").to_i.should eq(2)
  end

  it "codegens malloc" do
    run("p = Pointer(Int32).malloc(10_u64); p.value = 1; p.value + 1").to_i.should eq(2)
  end

  it "changes through var and reads from pointer" do
    run("
      x = 1
      px = x.ptr
      x = 2
      px.value
      ").to_i.should eq(2)
  end

  it "creates pointer by address" do
    run("
      x = Pointer(Int32).new(123_u64)
      x.address
    ").to_i.should eq(123)
  end

  it "calculates pointer diff" do
    run("
      x = 1
      (x.ptr + 1_i64) - x.ptr
    ").to_i.should eq(1)
  end
end
