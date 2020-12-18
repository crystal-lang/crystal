require "../../spec_helper"

CodeGenStructString = "lib LibFoo; struct Bar; x : Int32; y : Float32; end; end"

describe "Code gen: struct" do
  it "codegens struct property default value" do
    run("#{CodeGenStructString}; bar = Pointer(LibFoo::Bar).malloc(1_u64); bar.value.x").to_i.should eq(0)
  end

  it "codegens struct property setter" do
    run("#{CodeGenStructString}; bar = LibFoo::Bar.new; bar.y = 2.5_f32; bar.y").to_f32.should eq(2.5)
  end

  it "codegens struct property setter via pointer" do
    run("#{CodeGenStructString}; bar = Pointer(LibFoo::Bar).malloc(1_u64); bar.value.y = 2.5_f32; bar.value.y").to_f32.should eq(2.5)
  end

  it "codegens struct property setter via pointer" do
    run("#{CodeGenStructString}; bar = Pointer(LibFoo::Bar).malloc(1_u64); bar.value.y = 2.5_f32; bar.value.y").to_f32.should eq(2.5)
  end

  it "codegens set struct value with constant" do
    run("#{CodeGenStructString}; CONST = 1; bar = LibFoo::Bar.new; bar.x = CONST; bar.x").to_i.should eq(1)
  end

  it "codegens union inside struct" do
    run("
      lib LibFoo
        union Bar
          x : Int32
          y : Int64
        end

        struct Baz
          lala : Bar
        end
      end

      a = Pointer(LibFoo::Baz).malloc(1_u64)
      a.value.lala.x = 10
      a.value.lala.x
      ").to_i.should eq(10)
  end

  it "codegens struct get inside struct" do
    run("
      lib LibC
        struct Bar
          y : Int32
        end

        struct Foo
          x : Int32
          bar : Bar
        end
      end

      foo = Pointer(LibC::Foo).malloc(1_u64)
      (foo.as(Int32*) + 1_i64).value = 2

      foo.value.bar.y
      ").to_i.should eq(2)
  end

  it "codegens struct set inside struct" do
    run("
      lib LibC
        struct Bar
          y : Int32
        end

        struct Foo
          x : Int32
          bar : Bar
        end
      end

      foo = Pointer(LibC::Foo).malloc(1_u64)
      bar = LibC::Bar.new
      bar.y = 2
      foo.value.bar = bar

      foo.value.bar.y
      ").to_i.should eq(2)
  end

  it "codegens pointer malloc of struct" do
    run("
      lib LibC
        struct Foo
          x : Int32
        end
      end

      p = Pointer(LibC::Foo).malloc(1_u64)
      p.value.x = 1
      p.value.x
      ").to_i.should eq(1)
  end

  it "passes struct to method (1)" do
    run("
      lib LibC
        struct Foo
          x : Int32
        end
      end

      def foo(f)
        f.x = 2
        f
      end

      f1 = LibC::Foo.new
      f1.x = 1

      f2 = foo(f1)

      f1.x
      ").to_i.should eq(1)
  end

  it "passes struct to method (2)" do
    run("
      lib LibC
        struct Foo
          x : Int32
        end
      end

      def foo(f)
        f.x = 2
        f
      end

      f1 = LibC::Foo.new
      f1.x = 1

      f2 = foo(f1)
      f2.x
      ").to_i.should eq(2)
  end

  it "codegens struct access with -> and then ." do
    run("
      lib LibC
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

      e = Pointer(LibC::Event).malloc(1_u64)
      e.value.data.scalar.x
      ").to_i.should eq(0)
  end

  it "yields struct via ->" do
    run("
      lib LibC
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
        e = Pointer(LibC::Event).malloc(1_u64)
        yield e.value.data
      end

      foo do |data|
        data.scalar.x
      end
      ").to_i.should eq(0)
  end

  it "codegens assign struct to union" do
    run("
      lib LibFoo
        struct Coco
          x : Int32
        end
      end

      x = LibFoo::Coco.new
      c = x || 0
      c.is_a?(LibFoo::Coco)
    ").to_b.should be_true
  end

  it "codegens passing pointerof(struct) to fun" do
    run("
      lib LibC
        struct Foo
          a : Int32
        end
      end

      fun foo(x : LibC::Foo*) : Int32
        x.value.a
      end

      f = LibC::Foo.new
      f.a = 1

      foo pointerof(f)
      ").to_i.should eq(1)
  end

  it "builds struct setter with fun type (1)" do
    codegen(%(
      require "prelude"

      lib LibC
        struct Foo
          x : ->
        end
      end

      foo = LibC::Foo.new
      foo.x = -> { }
      ))
  end

  it "builds struct setter with fun type (2)" do
    codegen(%(
      require "prelude"

      lib LibC
        struct Foo
          x : ->
        end
      end

      foo = Pointer(LibC::Foo).malloc(1)
      foo.value.x = -> { }
      ))
  end

  it "allows using named arguments for new" do
    run(%(
      lib LibC
        struct Point
          x, y : Int32
        end
      end

      point = LibC::Point.new x: 1, y: 2
      point.x &+ point.y
      )).to_i.should eq(3)
  end

  it "does to_s" do
    run(%(
      require "prelude"

      lib LibFoo
        struct Point
          x, y : Int32
        end
      end

      point = LibFoo::Point.new x: 1, y: 2
      point.to_s
      )).to_string.should eq("LibFoo::Point(@x=1, @y=2)")
  end

  it "can access instance var from the outside (#1092)" do
    run(%(
      lib LibFoo
        struct Foo
          x : Int32
        end
      end

      f = LibFoo::Foo.new x: 123
      f.@x
      )).to_i.should eq(123)
  end

  it "automatically converts numeric type in struct field assignment" do
    run(%(
      lib LibFoo
        struct Foo
          x : Int32
        end
      end

      foo = LibFoo::Foo.new
      foo.x = 123_u8
      foo.x
      )).to_i.should eq(123)
  end

  it "automatically converts numeric union type in struct field assignment" do
    run(%(
      lib LibFoo
        struct Foo
          x : Int8
        end
      end

      a = 12345 || 12346_u16

      foo = LibFoo::Foo.new
      foo.x = a
      foo.x
      )).to_i.should eq(57)
  end

  it "automatically converts nil to pointer" do
    run(%(
      lib LibFoo
        struct Foo
          x : Int32*
        end
      end

      foo = LibFoo::Foo.new
      foo.x = Pointer(Int32).new(1234_u64)
      foo.x = nil
      foo.x.address
      )).to_i.should eq(0)
  end

  it "automatically converts by invoking to_unsafe" do
    run(%(
      lib LibFoo
        struct Foo
          x : Int32
        end
      end

      class Foo
        def to_unsafe
          123
        end
      end

      foo = LibFoo::Foo.new
      foo.x = Foo.new
      foo.x
      )).to_i.should eq(123)
  end

  it "sets instance var to proc" do
    run(%(
      require "prelude"

      lib LibFoo
        struct Foo
          x : Int32 -> Int32
        end
      end

      struct LibFoo::Foo
        def set(f)
          @x = f
        end
      end

      foo = LibFoo::Foo.new
      foo.set(->(x : Int32) { x + 1 })
      foo.x.call(1)
      )).to_i.should eq(2)
  end

  it "can access member of uninitialized struct behind type (#8774)" do
    run(%(
      lib LibFoo
        struct Foo
          x : Int32
        end

        type FooT = Foo
      end

      foo = uninitialized LibFoo::FooT
      foo.x
    ))
  end
end
