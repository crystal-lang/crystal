require "../../spec_helper"

describe "Semantic: lib" do
  it "types a varargs external" do
    assert_type("lib LibFoo; fun bar(x : Int32, ...) : Int32; end; LibFoo.bar(1, 1.5, 'a')") { int32 }
  end

  it "raises on undefined fun" do
    assert_error %(
      lib LibC
      end

      LibC.foo
      ),
      "undefined fun 'foo' for LibC"
  end

  it "raises wrong number of arguments" do
    assert_error %(
      lib LibC
        fun foo : Int32
      end

      LibC.foo 1
      ),
      "wrong number of arguments for 'LibC#foo' (given 1, expected 0)"
  end

  it "raises wrong argument type" do
    assert_error %(
      lib LibC
        fun foo(x : Int32) : Int32
      end

      LibC.foo 'a'
      ),
      "argument 'x' of 'LibC#foo' must be Int32, not Char"
  end

  it "reports error when changing var type and something breaks" do
    assert_error %(
      class LibFoo
        def initialize
          @value = 1
        end

        def value
          @value
        end

        def value=(@value : Char)
        end
      end

      f = LibFoo.new
      f.value + 1
      f.value = 'a'
      ),
      "undefined method '+' for Char"
  end

  it "reports error when changing instance var type and something breaks" do
    assert_error "
      lib Lib
        fun bar(c : Char)
      end

      class Foo
        def value=(@value : Int32 | Char)
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

  it "reports error on fun argument type not primitive like, Nil (#2994)" do
    assert_error "lib LibFoo; fun foo(x : Nil); end",
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

  it "reports error out can only be used with lib funs in named argument" do
    assert_error "foo(x: out x)",
      "out can only be used with lib funs"
  end

  it "reports error if using out with an already declared variable" do
    assert_error %(
      lib Lib
        fun foo(x : Int32*)
      end

      x = Pointer(Int32).malloc(1_u64)
      Lib.foo out x
      ),
      "variable 'x' is already defined, `out` must be used to define a variable, use another name"
  end

  it "allows invoking out with underscore " do
    assert_type(%(
      lib Lib
        fun foo(x : Int32*) : Float64
      end

      Lib.foo out _
      )) { float64 }
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

  it "types lib var get with forward declaration" do
    assert_type("
      lib LibC
        $errno : A

        alias A = Int32
      end

      LibC.errno
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
    lib_type = mod.types["LibC"].as(LibType)
    foo = lib_type.lookup_first_def("foo", false).as(External)
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

  it "allows passing double splat to LibC fun" do
    assert_type(%(
      lib LibC
        fun foo(x : Int32, y : Float64) : Float64
      end

      t = {y: 2.5, x: 3}
      LibC.foo **t
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
      "wrong number of link arguments (given 5, expected 1..4)"
  end

  it "errors if unknown named arg" do
    assert_error %(
      @[Link(boo: "bar")]
      lib LibFoo
      end
      ),
      "unknown link argument: 'boo' (valid arguments are 'lib', 'ldflags', 'static' and 'framework')"
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
    assert_error %(
      lib LibFoo
        fun foo : Int32
      end

      class Bar
        def self.foo
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

  it "correctly attached link flags if there's a macro if" do
    result = semantic(%(
      @[Link("SDL")]
      @[Link("SDLMain")]
      {% if flag?(:some_flag) %}
        @[Link(framework: "Cocoa")]
      {% end %}
      lib LibSDL
        fun init = SDL_Init(flags : UInt32) : Int32
      end

      LibSDL.init(0_u32)
      ))
    sdl = result.program.types["LibSDL"].as(LibType)
    attrs = sdl.link_attributes.not_nil!
    attrs.size.should eq(2)
    attrs[0].lib.should eq("SDL")
    attrs[1].lib.should eq("SDLMain")
  end

  it "supports forward references (#399)" do
    assert_type(%(
      lib LibFoo
        fun foo() : Bar*

        struct Bar
          x : Int32
        end
      end

      LibFoo.foo
      )) { pointer_of(types["LibFoo"].types["Bar"]) }
  end

  it "supports forward references with struct inside struct (#399)" do
    assert_type(%(
      lib LibFoo
        struct Bar
          x : Foo*
        end

        struct Foo
          x : Int32
        end
      end

      LibFoo::Bar.new.x
      )) { pointer_of(types["LibFoo"].types["Foo"]) }
  end

  it "errors if defines def on lib" do
    assert_error %(
      lib LibC
      end

      def LibC.foo
      end
      ),
      "can't define method in lib LibC"
  end

  it "reopens lib and adds more link attributes" do
    result = semantic(%(
      @[Link("SDL")]
      lib LibSDL
        fun init = SDL_Init(flags : UInt32) : Int32
      end

      @[Link("SDLMain")]
      lib LibSDL
      end

      LibSDL.init(0_u32)
      ))
    sdl = result.program.types["LibSDL"].as(LibType)
    attrs = sdl.link_attributes.not_nil!
    attrs.size.should eq(2)
    attrs[0].lib.should eq("SDL")
    attrs[1].lib.should eq("SDLMain")
  end

  it "reopens lib and adds same link attributes" do
    result = semantic(%(
      @[Link("SDL")]
      lib LibSDL
        fun init = SDL_Init(flags : UInt32) : Int32
      end

      @[Link("SDL")]
      lib LibSDL
      end

      LibSDL.init(0_u32)
      ))
    sdl = result.program.types["LibSDL"].as(LibType)
    attrs = sdl.link_attributes.not_nil!
    attrs.size.should eq(1)
    attrs[0].lib.should eq("SDL")
  end

  it "gathers link attributes from macro expression" do
    result = semantic(%(
      {% begin %}
        @[Link("SDL")]
      {% end %}
      lib LibSDL
        fun init = SDL_Init : Int32
      end

      LibSDL.init
      ))
    sdl = result.program.types["LibSDL"].as(LibType)
    attrs = sdl.link_attributes.not_nil!
    attrs.size.should eq(1)
    attrs[0].lib.should eq("SDL")
  end

  it "errors if using void as argument (related to #508)" do
    assert_error %(
      lib LibFoo
        fun foo(x : Void)
      end
      ),
      "can't use Void as argument type"
  end

  it "errors if using void via typedef as argument (related to #508)" do
    assert_error %(
      lib LibFoo
        type Foo = Void
        fun foo(x : Foo)
      end
      ),
      "can't use Void as argument type"
  end

  it "can use tuple as fun return" do
    assert_type(%(
      lib LibC
        fun foo : {Int32, Int32}
      end

      LibC.foo
      )) { tuple_of([int32, int32] of TypeVar) }
  end

  it "doesn't try to invoke unsafe for c struct/union (#1362)" do
    assert_error %(
      lib LibFoo
        struct Bar
        end

        fun foo(x : Bar*)
      end

      bar = LibFoo::Bar.new
      LibFoo.foo(bar)
      ),
      "argument 'x' of 'LibFoo#foo' must be Pointer(LibFoo::Bar), not LibFoo::Bar"
  end

  it "passes int as another integer type in variable" do
    assert_type(%(
      lib LibFoo
        fun foo(x : Int32) : Float64
      end

      a = 1_u8
      LibFoo.foo a
      )) { float64 }
  end

  it "passes float as another integer type in variable" do
    assert_type(%(
      lib LibFoo
        fun foo(x : Float32) : Int32
      end

      a = 1_f64
      LibFoo.foo a
      )) { int32 }
  end

  it "passes int as another integer type with literal" do
    assert_type(%(
      lib LibFoo
        fun foo(x : Int32) : Float64
      end

      LibFoo.foo 1_u8
      )) { float64 }
  end

  it "errors if invoking to_i32 and got error in that call" do
    assert_error %(
      lib LibFoo
        fun foo(x : Int32) : Float64
      end

      class Foo
        def to_i32
          1 + 'a'
        end
      end

      LibFoo.foo Foo.new
      ),
      "converting from Foo to Int32 by invoking 'to_i32'"
  end

  it "errors if invoking to_i32 and got wrong type" do
    assert_error %(
      lib LibFoo
        fun foo(x : Int32) : Float64
      end

      class Foo
        def to_i32
          'a'
        end
      end

      LibFoo.foo Foo.new
      ),
      "invoked 'to_i32' to convert from Foo to Int32, but got Char"
  end

  it "defines lib funs before funs with body" do
    assert_type(%(
      fun foo : Int32
        LibX.x
      end

      lib LibX
        fun x : Int32
      end

      foo
      )) { int32 }
  end

  it "errors if using out with varargs" do
    assert_error %(
      lib LibX
        fun x(...)
      end

      LibX.x(out z)
      ),
      "can't use out at varargs position: declare the variable with `z = uninitialized ...` and pass it with `pointerof(z)`"
  end

  it "errors if using out with void pointer (#2424)" do
    assert_error %(
      lib LibFoo
        fun foo(x : Void*)
      end

      LibFoo.foo(out x)
      ),
      "can't use out with Void* (argument 'x' of LibFoo.foo is Void*)"
  end

  it "errors if using out with void pointer through type" do
    assert_error %(
      lib LibFoo
        type Foo = Void
        fun foo(x : Foo*)
      end

      LibFoo.foo(out x)
      ),
      "can't use out with Void* (argument 'x' of LibFoo.foo is Void*)"
  end

  it "errors if using out with non-pointer" do
    assert_error %(
      lib LibFoo
        fun foo(x : Int32)
      end

      LibFoo.foo(out x)
      ),
      "argument 'x' of LibFoo.foo cannot be passed as 'out' because it is not a pointer"
  end

  it "errors if redefining fun with different signature (#2468)" do
    assert_error %(
      fun foo
      end

      fun foo(x : Int32)
      end
      ),
      "fun redefinition with different signature"
  end

  it "errors if using named args with variadic function" do
    assert_error %(
      lib LibC
        fun foo(x : Int32, y : UInt8, ...) : Int32
      end

      LibC.foo y: 1_u8, x: 1
      ),
      "can't use named args with variadic function"
  end

  it "errors if using unknown named arg" do
    assert_error %(
      lib LibC
        fun foo(x : Int32, y : UInt8) : Int32
      end

      LibC.foo y: 1_u8, x: 1, z: 2
      ),
      "no argument named 'z'"
  end

  it "errors if argument already specified" do
    assert_error %(
      lib LibC
        fun foo(x : Int32, y : UInt8) : Int32
      end

      LibC.foo 1, x: 2
      ),
      "argument 'x' already specified"
  end

  it "errors if missing arugment" do
    assert_error %(
      lib LibC
        fun foo(x : Int32, y : UInt8) : Int32
      end

      LibC.foo x: 2
      ),
      "missing argument: y"
  end

  it "errors if missing arugments" do
    assert_error %(
      lib LibC
        fun foo(x : Int32, y : UInt8, z: Int32) : Int32
      end

      LibC.foo y: 1_u8
      ),
      "missing arguments: x, z"
  end

  it "can use named args" do
    assert_type(%(
      lib LibC
        fun foo(x : Int32, y : UInt8) : Int32
      end

      LibC.foo y: 1_u8, x: 1
      )) { int32 }
  end

  it "can use out with named args" do
    assert_type(%(
      lib LibC
        fun foo(x : Int32*)
      end

      LibC.foo(x: out x)
      x
      )) { int32 }
  end

  it "types fun returning nothing as nil" do
    assert_type(%(
      lib LibFoo
        fun foo
      end

      LibFoo.foo
      )) { nil_type }
  end

  it "types fun returning void as nil" do
    assert_type(%(
      lib LibFoo
        fun foo : Void
      end

      LibFoo.foo
      )) { nil_type }
  end

  it "types fun returning nil as nil" do
    assert_type(%(
      lib LibFoo
        fun foo : Nil
      end

      LibFoo.foo
      )) { nil_type }
  end

  it "can use macros inside lib" do
    assert_type(%(
      lib LibFoo
        {% begin %}
          fun foo : Int32
        {% end %}
      end

      LibFoo.foo
      )) { int32 }
  end

  it "can use macros inside struct" do
    assert_type(%(
      lib LibFoo
        struct Foo
          {% begin %}
            x : Int32
          {% end %}
        end
      end

      LibFoo::Foo.new.x
      )) { int32 }
  end

  it "errors if defining incompatible funs with the same name in the same lib (#3045)" do
    assert_error %(
      lib LibFoo
        fun foo1 = foo
        fun foo2 = foo(x : Int32)
      end
      ),
      "fun redefinition with different signature"
  end

  it "errors if defining incompatible funs with the same name in different libs (#3045)" do
    assert_error %(
      lib LibFoo1
        fun foo1 = foo
      end

      lib LibFoo2
        fun foo2 = foo(x : Int32)
      end
      ),
      "fun redefinition with different signature"
  end

  it "specifies a call convention" do
    result = semantic(%(
      lib LibFoo
        @[CallConvention("X86_StdCall")]
        fun foo : Int32
      end
      ))
    foo = result.program.types["LibFoo"].lookup_first_def("foo", nil).as(External)
    foo.call_convention.should eq(LLVM::CallConvention::X86_StdCall)
  end

  it "specifies a call convention to a lib" do
    result = semantic(%(
      @[CallConvention("X86_StdCall")]
      lib LibFoo
        fun foo : Int32
      end
      ))
    foo = result.program.types["LibFoo"].lookup_first_def("foo", nil).as(External)
    foo.call_convention.should eq(LLVM::CallConvention::X86_StdCall)
  end

  it "errors if wrong number of arguments for CallConvention" do
    assert_error %(
      lib LibFoo
        @[CallConvention("X86_StdCall", "bar")]
        fun foo : Int32
      end
      ),
      "wrong number of arguments for attribute CallConvention (given 2, expected 1)"
  end

  it "errors if CallConvention argument is not a string" do
    assert_error %(
      lib LibFoo
        @[CallConvention(1)]
        fun foo : Int32
      end
      ),
      "argument to CallConvention must be a string"
  end

  it "errors if CallConvention argument is not a valid string" do
    assert_error %(
      lib LibFoo
        @[CallConvention("foo")]
        fun foo : Int32
      end
      ),
      "invalid call convention. Valid values are #{LLVM::CallConvention.values.join ", "}"
  end

  it "errors if assigning void lib call to var (#4414)" do
    assert_error %(
      lib LibFoo
        fun foo
      end

      x = LibFoo.foo
      ),
      "assigning Void return value of lib fun call has no effect"
  end

  it "errors if passing void lib call to call argument (#4414)" do
    assert_error %(
      lib LibFoo
        fun foo
      end

      def bar(x)
      end

      bar(LibFoo.foo)
      ),
      "passing Void return value of lib fun call has no effect"
  end
end
