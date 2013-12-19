#!/usr/bin/env bin/crystal -run
require "../../spec_helper"

CodeGenStructString = "lib Foo; struct Bar; x : Int32; y : Float32; end; end"

describe "Code gen: struct" do
  it "codegens struct property default value" do
    run("#{CodeGenStructString}; bar = Foo::Bar.new; bar.x").to_i.should eq(0)
  end

  it "codegens struct property setter" do
    run("#{CodeGenStructString}; bar = Foo::Bar.new; bar.y = 2.5_f32; bar.y").to_f32.should eq(2.5)
  end

  it "codegens struct property setter" do
    run("#{CodeGenStructString}; bar = Foo::Bar.new; p = pointerof(bar); p.value.y = 2.5_f32; bar.y").to_f32.should eq(2.5)
  end

  it "codegens set struct value with constant" do
    run("#{CodeGenStructString}; CONST = 1; bar = Foo::Bar.new; bar.x = CONST; bar.x").to_i.should eq(1)
  end

  it "codegens union inside struct" do
    run("
      lib Foo
        union Bar
          x : Int32
          y : Int64
        end

        struct Baz
          lala : Bar
        end
      end

      a = Foo::Baz.new
      a.lala.x = 10
      a.lala.x
      ").to_i.should eq(10)
  end

  it "codegens struct get inside struct" do
    run("
      lib C
        struct Bar
          y : Int32
        end

        struct Foo
          x : Int32
          bar : Bar
        end
      end

      foo = C::Foo.new
      (pointerof(foo).as(Int32) + 1_i64).value = 2

      foo.bar.y
      ").to_i.should eq(2)
  end

  it "codegens struct set inside struct" do
    run("
      lib C
        struct Bar
          y : Int32
        end

        struct Foo
          x : Int32
          bar : Bar
        end
      end

      foo = C::Foo.new
      bar = C::Bar.new
      bar.y = 2
      foo.bar = bar

      foo.bar.y
      ").to_i.should eq(2)
  end

  it "codegens pointer malloc of struct" do
    run("
      lib C
        struct Foo
          x : Int32
        end
      end

      p = Pointer(C::Foo).malloc(1_u64)
      p.value.x = 1
      p.value.x
      ").to_i.should eq(1)
  end
end
