require "../../spec_helper"

describe "Type inference: struct" do
  it "types struct" do
    result = assert_type("lib LibFoo; struct Bar; x : Int32; y : Float64; end; end; LibFoo::Bar") { types["LibFoo"].types["Bar"].metaclass }
    mod = result.program

    bar = mod.types["LibFoo"].types["Bar"] as CStructType
    expect(bar.vars["x"].type).to eq(mod.int32)
    expect(bar.vars["y"].type).to eq(mod.float64)
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
    ") { types["LibFoo"].types["Baz"] }
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
    ") { int32 }
  end

  it "types struct getter with keyword name" do
    assert_type("lib LibFoo; struct Bar; type : Int32; end; end; bar = LibFoo::Bar.new; bar.type") { int32 }
  end

  it "errors on struct if no field" do
    assert_error "lib LibFoo; struct Bar; x : Int32; end; end; f = LibFoo::Bar.new; f.y = 'a'",
      "struct LibFoo::Bar has no field 'y'"
  end

  it "errors on struct setter if different type" do
    assert_error "lib LibFoo; struct Bar; x : Int32; end; end; f = LibFoo::Bar.new; f.x = 'a'",
      "field 'x' of struct LibFoo::Bar has type Int32, not Char"
  end

  it "errors on struct setter if different type via new" do
    assert_error "lib LibFoo; struct Bar; x : Int32; end; end; f = Pointer(LibFoo::Bar).malloc(1_u64); f.value.x = 'a'",
      "field 'x' of struct LibFoo::Bar has type Int32, not Char"
  end

  it "types struct getter on pointer type" do
    assert_type("lib LibFoo; struct Bar; x : Int32*; end; end; b = LibFoo::Bar.new; b.x") { pointer_of(int32) }
  end

  it "errors if setting closure" do
    assert_error %(
      lib LibFoo
        struct Bar
          x : ->
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

  it "supports ifdef inside struct" do
    assert_type(%(
      lib LibC
        struct Foo
          ifdef some_flag
            a : Int32
          else
            a : Float64
          end
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
    result = infer_type(%(
      lib LibFoo
        @[Packed]
        struct Struct
          x, y : Int32
        end
      end
      ))
    foo_struct = result.program.types["LibFoo"].types["Struct"] as CStructType
    expect(foo_struct.packed).to be_true
  end
end
