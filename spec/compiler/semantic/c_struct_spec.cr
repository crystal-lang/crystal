require "../../spec_helper"

describe "Semantic: struct" do
  it "types struct" do
    result = assert_type("lib LibFoo; struct Bar; x : Int32; y : Float64; end; end; LibFoo::Bar") { types["LibFoo"].types["Bar"].metaclass }
    mod = result.program

    bar = mod.types["LibFoo"].types["Bar"].as(NonGenericClassType)
    bar.extern?.should be_true
    bar.extern_union?.should be_false
    bar.instance_vars["@x"].type.should eq(mod.int32)
    bar.instance_vars["@y"].type.should eq(mod.float64)
  end

  it "types Struct#new" do
    assert_type("lib LibFoo; struct Bar; x : Int32; y : Float64; end; end; LibFoo::Bar.new") do
      types["LibFoo"].types["Bar"]
    end
  end

  it "types struct setter" do
    assert_type("lib LibFoo; struct Bar; x : Int32; y : Float64; end; end; bar = LibFoo::Bar.new; bar.x = 1") { int32 }
  end

  it "types struct getter" do
    assert_type("lib LibFoo; struct Bar; x : Int32; y : Float64; end; end; bar = LibFoo::Bar.new; bar.x") { int32 }
  end

  it "types struct getter to struct" do
    assert_type("
      lib LibFoo
        struct Baz
          y : Int32
        end
        struct Bar
          x : Baz
        end
      end
      bar = Pointer(LibFoo::Bar).malloc(1_u64)
      bar.value.x
    ", inject_primitives: true) { types["LibFoo"].types["Baz"] }
  end

  it "types struct getter multiple levels via new" do
    assert_type("
      lib LibFoo
        struct Baz
          y : Int32
        end
        struct Bar
          x : Baz
        end
      end
      bar = Pointer(LibFoo::Bar).malloc(1_u64)
      bar.value.x.y
    ", inject_primitives: true) { int32 }
  end

  it "types struct getter with keyword name" do
    assert_type("lib LibFoo; struct Bar; type : Int32; end; end; bar = LibFoo::Bar.new; bar.type") { int32 }
  end

  it "errors on struct if no field" do
    assert_error "lib LibFoo; struct Bar; x : Int32; end; end; f = LibFoo::Bar.new; f.y = 'a'",
      "undefined method 'y=' for LibFoo::Bar"
  end

  it "errors on struct setter if different type" do
    assert_error "lib LibFoo; struct Bar; x : Int32; end; end; f = LibFoo::Bar.new; f.x = 'a'",
      "field 'x' of struct LibFoo::Bar has type Int32, not Char"
  end

  it "errors on struct setter if different type via new" do
    assert_error "lib LibFoo; struct Bar; x : Int32; end; end; f = Pointer(LibFoo::Bar).malloc(1_u64); f.value.x = 'a'",
      "field 'x' of struct LibFoo::Bar has type Int32, not Char", inject_primitives: true
  end

  it "types struct getter on pointer type" do
    assert_type("lib LibFoo; struct Bar; x : Int32*; end; end; b = LibFoo::Bar.new; b.x") { pointer_of(int32) }
  end

  it "errors if setting closure" do
    assert_error %(
      lib LibFoo
        struct Bar
          x : -> Int32
        end
      end

      a = 1

      bar = LibFoo::Bar.new
      bar.x = -> { a }
      ),
      "can't set closure as C struct member"
  end

  it "errors if already defined" do
    assert_error %(
      lib LibC
        struct Foo
          x : Int32
        end

        struct Foo
        end
      end
      ),
      "Foo is already defined"
  end

  it "errors if already defined with another type" do
    assert_error %(
      lib LibC
        enum Foo
          X
        end

        struct Foo
        end
      end
      ),
      "Foo is already defined as enum"
  end

  it "errors if already defined with another type (2)" do
    assert_error %(
      lib LibC
        union Foo
          x : Int32
        end

        struct Foo
        end
      end
      ),
      "Foo is already defined as union"
  end

  it "allows inline forward declaration" do
    assert_type(%(
      lib LibC
        struct Node
          next : Node*
        end
      end

      node = LibC::Node.new
      node.next
      )) { pointer_of(types["LibC"].types["Node"]) }
  end

  it "supports macro if inside struct" do
    assert_type(%(
      lib LibC
        struct Foo
          {% if flag?(:some_flag) %}
            a : Int32
          {% else %}
            a : Float64
          {% end %}
        end
      end

      LibC::Foo.new.a
      ), flags: "some_flag") { int32 }
  end

  it "includes another struct" do
    assert_type(%(
      lib LibC
        struct Foo
          a : Int32
        end

        struct Bar
          include Foo
        end
      end

      LibC::Bar.new.a
      )) { int32 }
  end

  it "errors if includes non-cstruct type" do
    assert_error %(
      lib LibC
        union Foo
          a : Int32
        end

        struct Bar
          include Foo
        end
      end

      LibC::Bar.new.a
      ),
      "can only include C struct, not union"
  end

  it "errors if includes unknown type" do
    assert_error %(
      lib LibC
        struct Bar
          include Foo
        end
      end

      LibC::Bar.new.a
      ),
      "undefined constant Foo"
  end

  it "errors if includes and field already exists" do
    assert_error %(
      lib LibC
        struct Foo
          a : Int32
        end

        struct Bar
          a : Float64
          include Foo
        end
      end

      LibC::Bar.new.a
      ),
      "struct LibC::Foo has a field named 'a', which LibC::Bar already defines"
  end

  it "errors if includes and field already exists, the other way around" do
    assert_error %(
      lib LibC
        struct Foo
          a : Int32
        end

        struct Bar
          include Foo
          a : Float64
        end
      end

      LibC::Bar.new.a
      ),
      "struct LibC::Bar already defines a field named 'a'"
  end

  it "marks as packed" do
    result = semantic(%(
      lib LibFoo
        @[Packed]
        struct Struct
          x, y : Int32
        end
      end
      ))
    foo_struct = result.program.types["LibFoo"].types["Struct"].as(NonGenericClassType)
    foo_struct.packed?.should be_true
  end

  it "errors on empty c struct (#633)" do
    assert_error %(
      lib LibFoo
        struct Struct
        end
      end
      ),
      "empty structs are disallowed"
  end

  it "errors if using void in struct field type" do
    assert_error %(
      lib LibFoo
        struct Struct
          x : Void
        end
      end
      ),
      "can't use Void as a struct field type"
  end

  it "errors if using void via typedef in struct field type" do
    assert_error %(
      lib LibFoo
        type MyVoid = Void

        struct Struct
          x : MyVoid
        end
      end
      ),
      "can't use Void as a struct field type"
  end

  it "can access instance var from the outside (#1092)" do
    assert_type(%(
      lib LibFoo
        struct Foo
          x : Int32
        end
      end

      f = LibFoo::Foo.new x: 123
      f.@x
      )) { int32 }
  end

  it "automatically converts numeric type in struct field assignment" do
    assert_type(%(
      lib LibFoo
        struct Foo
          x : Int32
        end
      end

      foo = LibFoo::Foo.new
      foo.x = 1_u8
      foo.x
      ), inject_primitives: true) { int32 }
  end

  it "errors if invoking to_i32! and got error in that call" do
    assert_error %(
      lib LibFoo
        struct Foo
          x : Int32
        end
      end

      class Foo
        def to_i32!
          1 + 'a'
        end
      end

      foo = LibFoo::Foo.new
      foo.x = Foo.new
      ),
      "converting from Foo to Int32 by invoking 'to_i32!'"
  end

  it "errors if invoking to_i32! and got wrong type" do
    assert_error %(
      lib LibFoo
        struct Foo
          x : Int32
        end
      end

      class Foo
        def to_i32!
          'a'
        end
      end

      foo = LibFoo::Foo.new
      foo.x = Foo.new
      ),
      "invoked 'to_i32!' to convert from Foo to Int32, but got Char"
  end

  it "errors if invoking to_unsafe and got error in that call" do
    assert_error %(
      lib LibFoo
        struct Foo
          x : Int32
        end
      end

      class Foo
        def to_unsafe
          1 + 'a'
        end
      end

      foo = LibFoo::Foo.new
      foo.x = Foo.new
      ),
      "expected argument #1 to 'Int32#+' to be Float32, Float64, Int128, Int16, Int32, Int64, Int8, UInt128, UInt16, UInt32, UInt64 or UInt8, not Char",
      inject_primitives: true
  end

  it "errors if invoking to_unsafe and got different type" do
    assert_error %(
      lib LibFoo
        struct Foo
          x : Int32
        end
      end

      class Foo
        def to_unsafe
          'a'
        end
      end

      foo = LibFoo::Foo.new
      foo.x = Foo.new
      ),
      "invoked 'to_unsafe' to convert from Foo to Int32, but got Char"
  end
end
