#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

CodeGenUnionString = "lib Foo; union Bar; x : Int32; y : Int64; z : Float32; end; end"

describe "Code gen: c union" do
  it "codegens union property default value" do
    run("#{CodeGenUnionString}; bar = Foo::Bar.new; bar->x").to_i.should eq(0)
  end

  it "codegens union property default value 2" do
    run("#{CodeGenUnionString}; bar = Foo::Bar.new; bar->z").to_f32.should eq(0)
  end

  it "codegens union property setter 1" do
    run("#{CodeGenUnionString}; bar :: Foo::Bar; bar.x = 42; bar.x").to_i.should eq(42)
  end

  it "codegens union property setter 2" do
    run("#{CodeGenUnionString}; bar :: Foo::Bar; bar.z = 42.0_f32; bar.z").to_f32.should eq(42.0)
  end

  it "codegens union property setter 1 via new" do
    run("#{CodeGenUnionString}; bar = Foo::Bar.new; bar->x = 42; bar->x").to_i.should eq(42)
  end

  it "codegens union property setter 2 via new" do
    run("#{CodeGenUnionString}; bar = Foo::Bar.new; bar->z = 42.0_f32; bar->z").to_f32.should eq(42.0)
  end

  it "codegens struct inside union" do
    run("
      lib Foo
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

      a = Foo::Bar.new
      a->z = Foo::Baz.new.value
      a->z->lala = 10
      a->z->lala
      ").to_i.should eq(10)
  end

  it "codegens assign c union to union" do
    run("
      lib Foo
        union Bar
          x : Int32
        end
      end

      bar :: Foo::Bar
      bar.x = 10
      x = bar || nil
      if x
        x.x
      else
        1
      end
      ").to_i.should eq(10)
  end
end
