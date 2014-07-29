#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

CodeGenStructString = "lib Foo; struct Bar; x : Int32; y : Float32; end; end"

describe "Code gen: struct" do
  it "codegens struct property default value" do
    run("#{CodeGenStructString}; bar = Pointer(Foo::Bar).malloc(1_u64); bar.value.x").to_i.should eq(0)
  end

  it "codegens struct property setter" do
    run("#{CodeGenStructString}; bar = Foo::Bar.new; bar.y = 2.5_f32; bar.y").to_f32.should eq(2.5)
  end

  it "codegens struct property setter via pointer" do
    run("#{CodeGenStructString}; bar = Pointer(Foo::Bar).malloc(1_u64); bar.value.y = 2.5_f32; bar.value.y").to_f32.should eq(2.5)
  end

  it "codegens struct property setter via pointer" do
    run("#{CodeGenStructString}; bar = Pointer(Foo::Bar).malloc(1_u64); bar.value.y = 2.5_f32; bar.value.y").to_f32.should eq(2.5)
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

      a = Pointer(Foo::Baz).malloc(1_u64)
      a.value.lala.x = 10
      a.value.lala.x
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

      foo = Pointer(C::Foo).malloc(1_u64)
      ((foo as Int32*) + 1_i64).value = 2

      foo.value.bar.y
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

      foo = Pointer(C::Foo).malloc(1_u64)
      bar = C::Bar.new
      bar.y = 2
      foo.value.bar = bar

      foo.value.bar.y
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

  it "passes struct to method (1)" do
    run("
      lib C
        struct Foo
          x : Int32
        end
      end

      def foo(f)
        f.x = 2
        f
      end

      f1 = C::Foo.new
      f1.x = 1

      f2 = foo(f1)

      f1.x
      ").to_i.should eq(1)
  end

  it "passes struct to method (2)" do
    run("
      lib C
        struct Foo
          x : Int32
        end
      end

      def foo(f)
        f.x = 2
        f
      end

      f1 = C::Foo.new
      f1.x = 1

      f2 = foo(f1)
      f2.x
      ").to_i.should eq(2)
  end

  it "codegens struct access with -> and then ." do
    run("
      lib C
        struct ScalarEvent
          x : Int32
        end

        union EventData
          scalar : ScalarEvent
        end

        struct Event
          data : EventData
        end
      end

      e = Pointer(C::Event).malloc(1_u64)
      e.value.data.scalar.x
      ").to_i.should eq(0)
  end

  it "yields struct via ->" do
    run("
      lib C
        struct ScalarEvent
          x : Int32
        end

        union EventData
          scalar : ScalarEvent
        end

        struct Event
          data : EventData
        end
      end

      def foo
        e = Pointer(C::Event).malloc(1_u64)
        yield e.value.data
      end

      foo do |data|
        data.scalar.x
      end
      ").to_i.should eq(0)
  end

  it "codegens assign struct to union" do
    run("
      lib Foo
        struct Coco
          x : Int32
        end
      end

      x = Foo::Coco.new
      c = x || 0
      c.is_a?(Foo::Coco)
    ").to_b.should be_true
  end

  it "codegens passing pointerof(struct) to fun" do
    run("
      lib C
        struct Foo
          a : Int32
        end
      end

      fun foo(x : C::Foo*) : Int32
        x.value.a
      end

      f = C::Foo.new
      f.a = 1

      foo pointerof(f)
      ").to_i.should eq(1)
  end

  it "builds struct setter with fun type (1)" do
    build(%(
      require "prelude"

      lib C
        struct Foo
          x : ->
        end
      end

      foo = C::Foo.new
      foo.x = -> { }
      ))
  end

  it "builds struct setter with fun type (2)" do
    build(%(
      require "prelude"

      lib C
        struct Foo
          x : ->
        end
      end

      foo = Pointer(C::Foo).malloc(1)
      foo.value.x = -> { }
      ))
  end

  it "allows forward delcarations" do
    run(%(
      lib C
        struct A; end
        struct B; end

        struct A
          x : B*
          y : Int32
        end

        struct B
          x : A*
          y : Int32
        end
      end

      a = C::A.new
      a.y = 1

      b = Pointer(C::B).malloc(1_u64)
      b.value.y = 2
      a.x = b

      a.y + a.x.value.y
      )).to_i.should eq(3)
  end
end
