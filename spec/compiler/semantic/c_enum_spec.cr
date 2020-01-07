require "../../spec_helper"

describe "Semantic: c enum" do
  it "types enum value" do
    assert_type("lib LibFoo; enum Bar; X; Y; Z = 10; W; end; end; LibFoo::Bar::X") { types["LibFoo"].types["Bar"] }
  end

  it "allows using an enum as a type in a fun" do
    assert_type("
      lib LibC
        enum Foo
          A
        end
        fun my_mega_function(y : Foo) : Foo
      end

      LibC.my_mega_function(LibC::Foo::A)
    ") { types["LibC"].types["Foo"] }
  end

  it "allows using an enum as a type in a struct" do
    assert_type("
      lib LibC
        enum Foo
          A
        end
        struct Bar
          x : Foo
        end
      end

      f = LibC::Bar.new
      f.x = LibC::Foo::A
      f.x
    ") { types["LibC"].types["Foo"] }
  end

  it "types enum value with base type" do
    assert_type("lib LibFoo; enum Bar : Int16; X; end; end; LibFoo::Bar::X") { types["LibFoo"].types["Bar"] }
  end

  it "errors if enum base type is not an integer" do
    assert_error "lib LibFoo; enum Bar : Float32; X; end; end; LibFoo::Bar::X",
      "enum base type must be an integer type"
  end

  it "errors if enum value is different from default (Int32) (#194)" do
    assert_error "lib LibFoo; enum Bar; X = 0x00000001_u32; end; end; LibFoo::Bar::X",
      "enum value must be an Int32"
  end
end
