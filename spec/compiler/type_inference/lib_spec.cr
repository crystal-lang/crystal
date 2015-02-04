require "../../spec_helper"

describe "Type inference: lib" do
  it "types a varargs external" do
    assert_type("lib LibFoo; fun bar(x : Int32, ...) : Int32; end; LibFoo.bar(1, 1.5, 'a')") { int32 }
  end

  it "raises on undefined fun" do
    assert_error("lib LibC; end; LibC.foo", "undefined fun 'foo' for LibC")
  end

  it "raises wrong number of arguments" do
    assert_error("lib LibC; fun foo : Int32; end; LibC.foo 1", "wrong number of arguments for 'LibC#foo' (1 for 0)")
  end

  it "raises wrong argument type" do
    assert_error("lib LibC; fun foo(x : Int32) : Int32; end; LibC.foo 1.5", "argument 'x' of 'LibC#foo' must be Int32, not Float64")
  end

  it "reports error when changing var type and something breaks" do
    assert_error "class LibFoo; def initialize; @value = 1; end; def value; @value; end; def value=(@value); end; end; f = LibFoo.new; f.value + 1; f.value = 'a'",
      "undefined method '+' for Char"
  end

  it "reports error when changing instance var type and something breaks" do
    assert_error "
      lib Lib
        fun bar(c : Char)
      end

      class Foo
        def value=(@value)
        end
        def value
          @value
        end
      end

      def foo(x)
        x.value = 'a'
        Lib.bar x.value
      end

      f = Foo.new
      foo(f)

      f.value = 1
      ",
      "argument 'c' of 'Lib#bar' must be Char"
  end

  it "reports error on fun argument type not primitive like" do
    assert_error "lib LibFoo; fun foo(x : Reference); end",
      "only primitive types"
  end

  it "reports error on fun return type not primitive like" do
    assert_error "lib LibFoo; fun foo : Reference; end",
      "only primitive types"
  end

  it "reports error on struct field type not primitive like" do
    assert_error "lib LibFoo; struct Foo; x : Reference; end; end",
      "only primitive types"
  end

  it "reports error on typedef type not primitive like" do
    assert_error "lib LibFoo; type Foo = Reference; end",
      "only primitive types"
  end

  it "reports error out can only be used with lib funs" do
    assert_error "foo(out x)",
      "out can only be used with lib funs"
  end

  it "reports redefinition of fun with different signature" do
    assert_error "
      lib LibC
        fun foo : Int32
        fun foo : Int64
      end
      ",
      "fun redefinition with different signature"
  end

  it "types lib var get" do
    assert_type("
      lib LibC
        $errno : Int32
      end

      LibC.errno
      ") { int32 }
  end

  it "types lib var set" do
    assert_type("
      lib LibC
        $errno : Int32
      end

      LibC.errno = 1
      ") { int32 }
  end

  it "defined fun with aliased type" do
    assert_type("
      lib LibC
        alias SizeT = Int32
        fun foo(x : SizeT) : SizeT
      end

      LibC.foo(1)
      ") { int32 }
  end

  it "overrides definition of fun" do
    result = assert_type("
      lib LibC
        fun foo(x : Int32) : Float64
      end

      lib LibC
        fun foo = bar(x : Int32) : Float64
      end

      LibC.foo(1)
      ") { float64 }
    mod = result.program
    lib_type = mod.types["LibC"] as LibType
    foo = lib_type.lookup_first_def("foo", false) as External
    foo.real_name.should eq("bar")
  end

  it "error if passing type to LibC with to_unsafe but type doesn't match" do
    assert_error "
      lib LibC
        fun foo(x : Int32) : Int32
      end

      class Foo
        def to_unsafe
          'a'
        end
      end

      LibC.foo Foo.new
      ", "argument 'x' of 'LibC#foo' must be Int32, not Foo (nor Char returned by 'Foo#to_unsafe')"
  end

  it "error if passing nil to pointer through to_unsafe" do
    assert_error "
      lib LibC
        fun foo(x : Void*) : Int32
      end

      class Foo
        def to_unsafe
          nil
        end
      end

      LibC.foo Foo.new
      ", "argument 'x' of 'LibC#foo' must be Pointer(Void), not Foo (nor Nil returned by 'Foo#to_unsafe')"
  end

  it "error if passing non primitive type as varargs" do
    assert_error "
      lib LibC
        fun foo(x : Int32, ...)
      end

      class Foo
      end

      LibC.foo 1, Foo.new
      ", "argument #2 of 'LibC#foo' is not a primitive type and no Foo#to_unsafe method found"
  end

  it "error if passing non primitive type as varargs invoking to_unsafe" do
    assert_error "
      lib LibC
        fun foo(x : Int32, ...)
      end

      class Bar
      end

      class Foo
        def to_unsafe
          Bar.new
        end
      end

      LibC.foo 1, Foo.new
      ", "converted Foo invoking to_unsafe, but Bar is not a primitive type"
  end

  it "allows passing splat to LibC fun" do
    assert_type(%(
      lib LibC
        fun foo(x : Int32, y : Float64, ...) : Float64
      end

      t = {1, 2.5, 3, 4}
      LibC.foo *t
      )) { float64 }
  end

  it "errors if applying wrong attribute" do
    assert_error %(
      @[Bar]
      lib LibFoo
      end
      ),
      "illegal attribute for lib, valid attributes are: Link"
  end

  it "errors if missing link arguments" do
    assert_error %(
      @[Link]
      lib LibFoo
      end
      ),
      "missing link arguments: must at least specify a library name"
  end

  it "errors if first argument is not a string" do
    assert_error %(
      @[Link(1)]
      lib LibFoo
      end
      ),
      "'lib' link argument must be a String"
  end

  it "errors if second argument is not a string" do
    assert_error %(
      @[Link("foo", 1)]
      lib LibFoo
      end
      ),
      "'ldflags' link argument must be a String"
  end

  it "errors if third argument is not a bool" do
    assert_error %(
      @[Link("foo", "bar", 1)]
      lib LibFoo
      end
      ),
      "'static' link argument must be a Bool"
  end

  it "errors if foruth argument is not a bool" do
    assert_error %(
      @[Link("foo", "bar", true, 1)]
      lib LibFoo
      end
      ),
      "'framework' link argument must be a String"
  end

  it "errors if too many link arguments" do
    assert_error %(
      @[Link("foo", "bar", true, "Cocoa", 1)]
      lib LibFoo
      end
      ),
      "wrong number of link arguments (5 for 1..4)"
  end

it "errors if unknown named arg" do
    assert_error %(
      @[Link(boo: "bar")]
      lib LibFoo
      end
      ),
      "unkonwn link argument: 'boo' (valid arguments are 'lib', 'ldflags', 'static' and 'framework')"
  end

  it "errors if lib already specified with positional argument" do
    assert_error %(
      @[Link("foo", lib: "bar")]
      lib LibFoo
      end
      ),
      "'lib' link argument already specified"
  end

  it "errors if lib named arg is not a String" do
    assert_error %(
      @[Link(lib: 1)]
      lib LibFoo
      end
      ),
      "'lib' link argument must be a String"
  end

  it "clears attributes after lib" do
    assert_type(%(
      @[Link("foo")]
      lib LibFoo
        fun foo
      end
      1
      )) { int32 }
  end

  it "allows invoking lib call without obj inside lib" do
    assert_type(%(
      lib LibFoo
        fun foo : Int32

        A = foo
      end

      LibFoo::A
      )) { int32 }
  end

  it "errors if lib fun call is part of dispatch" do
    assert_error  %(
      lib LibFoo
        fun foo : Int32
      end

      class Bar
        def foo
        end
      end

      (LibFoo || Bar).foo
      ),
      "lib fun call is not supported in dispatch"
  end

  it "allows passing nil or pointer to arg expecting pointer" do
    assert_type(%(
      lib Foo
        fun foo(x : Int32*) : Int64
      end

      a = 1 == 1 ? nil : Pointer(Int32).malloc(1_u64)
      Foo.foo(a)
      )) { int64 }
  end

  it "correctly attached link flags if there's an ifdef" do
    result = infer_type(%(
      @[Link("SDL")]
      @[Link("SDLMain")]
      @[Link(framework: "Cocoa")] ifdef some_flag
      lib LibSDL
        fun init = SDL_Init(flags : UInt32) : Int32
      end

      LibSDL.init(0_u32)
      ))
    sdl = result.program.types["LibSDL"] as LibType
    attrs = sdl.link_attributes.not_nil!
    attrs.length.should eq(2)
    attrs[0].lib.should eq("SDL")
    attrs[1].lib.should eq("SDLMain")
  end
end
