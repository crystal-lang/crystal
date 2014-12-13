require "../../spec_helper"

describe "Type inference: lib" do
  it "types a varargs external" do
    assert_type("lib Foo; fun bar(x : Int32, ...) : Int32; end; Foo.bar(1, 1.5, 'a')") { int32 }
  end

  it "raises on undefined fun" do
    assert_error("lib C; end; C.foo", "undefined fun 'foo' for C")
  end

  it "raises wrong number of arguments" do
    assert_error("lib C; fun foo : Int32; end; C.foo 1", "wrong number of arguments for 'C#foo' (1 for 0)")
  end

  it "raises wrong argument type" do
    assert_error("lib C; fun foo(x : Int32) : Int32; end; C.foo 1.5", "argument 'x' of 'C#foo' must be Int32, not Float64")
  end

  it "reports error when changing var type and something breaks" do
    assert_error "class Foo; def initialize; @value = 1; end; def value; @value; end; def value=(@value); end; end; f = Foo.new; f.value + 1; f.value = 'a'",
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
    assert_error "lib Foo; fun foo(x : Reference); end",
      "only primitive types"
  end

  it "reports error on fun return type not primitive like" do
    assert_error "lib Foo; fun foo : Reference; end",
      "only primitive types"
  end

  it "reports error on struct field type not primitive like" do
    assert_error "lib Foo; struct Foo; x : Reference; end; end",
      "only primitive types"
  end

  it "reports error on typedef type not primitive like" do
    assert_error "lib Foo; type Foo = Reference; end",
      "only primitive types"
  end

  it "reports error out can only be used with lib funs" do
    assert_error "foo(out x)",
      "out can only be used with lib funs"
  end

  it "reports redefinition of fun with different signature" do
    assert_error "
      lib C
        fun foo : Int32
        fun foo : Int64
      end
      ",
      "fun redefinition with different signature"
  end

  it "types lib var get" do
    assert_type("
      lib C
        $errno : Int32
      end

      C.errno
      ") { int32 }
  end

  it "types lib var set" do
    assert_type("
      lib C
        $errno : Int32
      end

      C.errno = 1
      ") { int32 }
  end

  it "defined fun with aliased type" do
    assert_type("
      lib C
        alias SizeT = Int32
        fun foo(x : SizeT) : SizeT
      end

      C.foo(1)
      ") { int32 }
  end

  it "overrides definition of fun" do
    result = assert_type("
      lib C
        fun foo(x : Int32) : Float64
      end

      lib C
        fun foo = bar(x : Int32) : Float64
      end

      C.foo(1)
      ") { float64 }
    mod = result.program
    lib_type = mod.types["C"] as LibType
    foo = lib_type.lookup_first_def("foo", false) as External
    foo.real_name.should eq("bar")
  end

  it "error if passing type to C with to_unsafe but type doesn't match" do
    assert_error "
      lib C
        fun foo(x : Int32) : Int32
      end

      class Foo
        def to_unsafe
          'a'
        end
      end

      C.foo Foo.new
      ", "argument 'x' of 'C#foo' must be Int32, not Foo (nor Char returned by 'Foo#to_unsafe')"
  end

  it "error if passing nil to pointer through to_unsafe" do
    assert_error "
      lib C
        fun foo(x : Void*) : Int32
      end

      class Foo
        def to_unsafe
          nil
        end
      end

      C.foo Foo.new
      ", "argument 'x' of 'C#foo' must be Pointer(Void), not Foo (nor Nil returned by 'Foo#to_unsafe')"
  end

  it "error if passing non primitive type as varargs" do
    assert_error "
      lib C
        fun foo(x : Int32, ...)
      end

      class Foo
      end

      C.foo 1, Foo.new
      ", "argument #2 of 'C#foo' is not a primitive type and no Foo#to_unsafe method found"
  end

  it "error if passing non primitive type as varargs invoking to_unsafe" do
    assert_error "
      lib C
        fun foo(x : Int32, ...)
      end

      class Bar
      end

      class Foo
        def to_unsafe
          Bar.new
        end
      end

      C.foo 1, Foo.new
      ", "converted Foo invoking to_unsafe, but Bar is not a primitive type"
  end

  it "allows passing splat to C fun" do
    assert_type(%(
      lib C
        fun foo(x : Int32, y : Float64, ...) : Float64
      end

      t = {1, 2.5, 3, 4}
      C.foo *t
      )) { float64 }
  end

  it "errors if applying wrong attribute" do
    assert_error %(
      @[Bar]
      lib Foo
      end
      ),
      "illegal attribute for lib, valid attributes are: Link"
  end

  it "errors if missing link arguments" do
    assert_error %(
      @[Link]
      lib Foo
      end
      ),
      "missing link arguments: must at least specify a library name"
  end

  it "errors if first argument is not a string" do
    assert_error %(
      @[Link(1)]
      lib Foo
      end
      ),
      "'lib' link argument must be a String"
  end

  it "errors if second argument is not a string" do
    assert_error %(
      @[Link("foo", 1)]
      lib Foo
      end
      ),
      "'ldflags' link argument must be a String"
  end

  it "errors if third argument is not a bool" do
    assert_error %(
      @[Link("foo", "bar", 1)]
      lib Foo
      end
      ),
      "'static' link argument must be a Bool"
  end

  it "errors if foruth argument is not a bool" do
    assert_error %(
      @[Link("foo", "bar", true, 1)]
      lib Foo
      end
      ),
      "'framework' link argument must be a String"
  end

  it "errors if too many link arguments" do
    assert_error %(
      @[Link("foo", "bar", true, "Cocoa", 1)]
      lib Foo
      end
      ),
      "wrong number of link arguments (5 for 1..4)"
  end

it "errors if unknown named arg" do
    assert_error %(
      @[Link(boo: "bar")]
      lib Foo
      end
      ),
      "unkonwn link argument: 'boo' (valid arguments are 'lib', 'ldflags', 'static' and 'framework')"
  end

  it "errors if lib already specified with positional argument" do
    assert_error %(
      @[Link("foo", lib: "bar")]
      lib Foo
      end
      ),
      "'lib' link argument already specified"
  end

  it "errors if lib named arg is not a String" do
    assert_error %(
      @[Link(lib: 1)]
      lib Foo
      end
      ),
      "'lib' link argument must be a String"
  end

  it "clears attributes after lib" do
    assert_type(%(
      @[Link("foo")]
      lib Foo
        fun foo
      end
      1
      )) { int32 }
  end
end
