#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: struct" do
  it "types struct" do
    result = assert_type("lib Foo; struct Bar; x : Int32; y : Float64; end; end; Foo::Bar") { types["Foo"].types["Bar"].metaclass }
    mod = result.program

    bar = mod.types["Foo"].types["Bar"]
    assert_type bar, CStructType

    bar.vars["x"].type.should eq(mod.int32)
    bar.vars["y"].type.should eq(mod.float64)
  end

  it "types Struct#new" do
    assert_type("lib Foo; struct Bar; x : Int32; y : Float64; end; end; Foo::Bar.new") do
      pointer_of(types["Foo"].types["Bar"])
    end
  end

  it "types struct setter" do
    assert_type("lib Foo; struct Bar; x : Int32; y : Float64; end; end; bar :: Foo::Bar; bar.x = 1") { int32 }
  end

  it "types struct getter" do
    assert_type("lib Foo; struct Bar; x : Int32; y : Float64; end; end; bar :: Foo::Bar; bar.x") { int32 }
  end

  it "types struct setter via new" do
    assert_type("lib Foo; struct Bar; x : Int32; y : Float64; end; end; bar = Foo::Bar.new; bar->x = 1") { int32 }
  end

  it "types struct getter via new" do
    assert_type("lib Foo; struct Bar; x : Int32; y : Float64; end; end; bar = Foo::Bar.new; bar->x") { int32 }
  end

  it "types struct getter to struct" do
    assert_type("
      lib Foo
        struct Baz
          y : Int32
        end
        struct Bar
          x : Baz
        end
      end
      bar = Foo::Bar.new
      bar->x
    ") { types["Foo"].types["Baz"] }
  end

  it "types struct getter multiple levels via new" do
    assert_type("
      lib Foo
        struct Baz
          y : Int32
        end
        struct Bar
          x : Baz
        end
      end
      bar = Foo::Bar.new
      bar->x->y
    ") { int32 }
  end

  it "types struct getter with keyword name" do
    assert_type("lib Foo; struct Bar; type : Int32; end; end; bar :: Foo::Bar; bar.type") { int32 }
  end

  it "errors on struct if no field" do
    assert_error "lib Foo; struct Bar; x : Int32; end; end; f :: Foo::Bar; f.y = 'a'",
      "struct Foo::Bar has no field 'y'"
  end

  it "errors on struct setter if different type" do
    assert_error "lib Foo; struct Bar; x : Int32; end; end; f :: Foo::Bar; f.x = 'a'",
      "field 'x' of struct Foo::Bar has type Int32, not Char"
  end

  it "errors on struct setter if different type via new" do
    assert_error "lib Foo; struct Bar; x : Int32; end; end; f = Foo::Bar.new; f->x = 'a'",
      "field 'x' of struct Foo::Bar has type Int32, not Char"
  end

  it "types struct getter on pointer type" do
    assert_type("lib Foo; struct Bar; x : Int32*; end; end; b :: Foo::Bar; b.x") { pointer_of(int32) }
  end

  it "types pointerof to indirect read" do
    assert_type("
      lib Foo
        struct Bar
          x : Int32
          y : Float64
        end
      end

      f = Foo::Bar.new
      pointerof(f->y)
      ") { pointer_of(float64) }
  end
end
