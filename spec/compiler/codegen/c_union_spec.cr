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
    run("
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
      ").to_i.should eq(10)
  end

  it "codegens assign c union to union" do
    run("
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
      ").to_i.should eq(10)
  end

  it "builds union setter with fun type" do
    build(%(
      require "prelude"

      lib LibC
        union Foo
          x : ->
        end
      end

      foo = LibC::Foo.new
      foo.x = -> { }
      ))
  end
end
