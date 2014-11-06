#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Type inference: c enum" do
  it "types enum value" do
    assert_type("lib Foo; enum Bar; X, Y, Z = 10, W; end; end; Foo::Bar::X") { types["Foo"].types["Bar"] }
  end

  it "allows using an enum as a type in a fun" do
    assert_type("
      lib C
        enum Foo
          A
        end
        fun my_mega_function(y : Foo) : Foo
      end

      C.my_mega_function(C::Foo::A)
    ") { types["C"].types["Foo"] }
  end

  it "allows using an enum as a type in a struct" do
    assert_type("
      lib C
        enum Foo
          A
        end
        struct Bar
          x : Foo
        end
      end

      f = C::Bar.new
      f.x = C::Foo::A
      f.x
    ") { types["C"].types["Foo"] }
  end

  it "types enum value with base type" do
    assert_type("lib Foo; enum Bar : Int16; X; end; end; Foo::Bar::X") { types["Foo"].types["Bar"] }
  end

  it "errors if enum base type is not an integer" do
    assert_error "lib Foo; enum Bar : Float32; X; end; end; Foo::Bar::X",
      "enum base type must be an integer type"
  end
end
