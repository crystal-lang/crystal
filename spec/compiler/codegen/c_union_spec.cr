require "../../spec_helper"

CodeGenUnionString = "lib LibFoo; union Bar; x : Int32; y : Int64; z : Float32; end; end"

describe "Code gen: c union" do
  it "codegens union property default value" do
    run("#{CodeGenUnionString}; bar = Pointer(LibFoo::Bar).malloc(1_u64); bar.value.x").to_i.should eq(0)
  end

  it "codegens union property default value 2" do
    run("#{CodeGenUnionString}; bar = Pointer(LibFoo::Bar).malloc(1_u64); bar.value.z").to_f32.should eq(0)
  end

  it "codegens union property setter 1" do
    run("#{CodeGenUnionString}; bar = LibFoo::Bar.new; bar.x = 42; bar.x").to_i.should eq(42)
  end

  it "codegens union property setter 2" do
    run("#{CodeGenUnionString}; bar = LibFoo::Bar.new; bar.z = 42.0_f32; bar.z").to_f32.should eq(42.0)
  end

  it "codegens union property setter 1 via pointer" do
    run("#{CodeGenUnionString}; bar = Pointer(LibFoo::Bar).malloc(1_u64); bar.value.x = 42; bar.value.x").to_i.should eq(42)
  end

  it "codegens union property setter 2 via pointer" do
    run("#{CodeGenUnionString}; bar = Pointer(LibFoo::Bar).malloc(1_u64); bar.value.z = 42.0_f32; bar.value.z").to_f32.should eq(42.0)
  end

  it "codegens struct inside union" do
    run(<<-CRYSTAL).to_i.should eq(10)
      lib LibFoo
        struct Baz
          lele : Int64
          lala : Int32
        end

        union Bar
          x : Int32
          y : Int64
          z : Baz
        end
      end

      a = Pointer(LibFoo::Bar).malloc(1_u64)
      a.value.z = LibFoo::Baz.new
      a.value.z.lala = 10
      a.value.z.lala
      CRYSTAL
  end

  it "codegens assign c union to union" do
    run(<<-CRYSTAL).to_i.should eq(10)
      lib LibFoo
        union Bar
          x : Int32
        end
      end

      bar = LibFoo::Bar.new
      bar.x = 10
      x = bar || nil
      if x
        x.x
      else
        1
      end
      CRYSTAL
  end

  it "builds union setter with fun type" do
    codegen(<<-CRYSTAL)
      require "prelude"

      lib LibC
        union Foo
          x : ->
        end
      end

      foo = LibC::Foo.new
      foo.x = -> { }
      CRYSTAL
  end

  it "does to_s" do
    run(<<-CRYSTAL).to_string.should eq("LibNVG::Color(@array=0)")
      require "prelude"

      lib LibNVG
        union Color
          array: Int32
        end
      end

      color = LibNVG::Color.new
      color.to_s
      CRYSTAL
  end

  it "automatically converts numeric type in field assignment" do
    run(<<-CRYSTAL).to_i.should eq(57)
      lib LibFoo
        union Foo
          x : Int8
        end
      end

      a = 12345

      foo = LibFoo::Foo.new
      foo.x = a
      foo.x
      CRYSTAL
  end

  it "automatically converts numeric union type in field assignment" do
    run(<<-CRYSTAL).to_i.should eq(57)
      lib LibFoo
        union Foo
          x : Int8
        end
      end

      a = 12345 || 12346_u16

      foo = LibFoo::Foo.new
      foo.x = a
      foo.x
      CRYSTAL
  end

  it "automatically converts by invoking to_unsafe" do
    run(<<-CRYSTAL).to_i.should eq(123)
      lib LibFoo
        union Foo
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
      CRYSTAL
  end

  it "aligns to the member with biggest align requirements" do
    run(<<-CRYSTAL).to_i.should eq(0x5858)
      lib LibFoo
        union Foo
          bytes : UInt8[4]
          short : UInt16
        end

        struct Bar
          a : Int8
          b : Foo
        end
      end

      class String
        def to_unsafe
          pointerof(@c)
        end
      end

      str = "00XX0"
      foo = str.to_unsafe.as(LibFoo::Bar*)
      foo.value.b.short.to_i
      CRYSTAL
  end

  it "fills union type to the max size" do
    run(<<-CRYSTAL).to_i.should eq(6)
      lib LibFoo
        union Foo
          bytes : UInt8[4]
          short : UInt16
        end

        struct Bar
          a : Int8
          b : Foo
        end
      end

      sizeof(LibFoo::Bar)
      CRYSTAL
  end

  it "reads union instance var" do
    run(<<-CRYSTAL).to_i.should eq(42)
      lib LibFoo
        union Foo
          char : Char
          int : Int32
        end
      end

      struct LibFoo::Foo
        def read_int
          @int
        end
      end

      foo = LibFoo::Foo.new
      foo.int = 42
      foo.read_int
      CRYSTAL
  end

  it "moves unions around correctly (#12550)" do
    run(<<-CRYSTAL).to_i.should eq((1..6).sum)
      require "prelude"

      lib Lib
        struct Foo
          x : UInt8
          y : UInt16
        end

        union Bar
          foo : Foo
          padding : UInt8[6] # larger than `Foo`
        end
      end

      def foo
        a = uninitialized Lib::Bar
        a.padding.fill { |i| 1_u8 + i }
        a
      end

      foo.padding.sum
      CRYSTAL
  end
end
