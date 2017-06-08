require "../../spec_helper"

describe "Code gen: lib" do
  pending "codegens lib var set and get" do
    run("
      lib LibC
        $errno : Int32
      end

      LibC.errno = 1
      LibC.errno
      ").to_i.should eq(1)
  end

  it "call to void function" do
    run("
      lib LibC
        fun srandom(x : UInt32) : Void
      end

      def foo
        LibC.srandom(0_u32)
      end

      foo
    ")
  end

  it "allows passing type to LibC if it has a coverter with to_unsafe" do
    codegen("
      lib LibC
        fun foo(x : Int32) : Int32
      end

      class Foo
        def to_unsafe
          1
        end
      end

      LibC.foo Foo.new
      ")
  end

  it "allows passing type to LibC if it has a coverter with to_unsafe (bug)" do
    codegen(%(
      require "prelude"

      lib LibC
        fun foo(x : UInt8*)
      end

      def foo
        yield 1
      end

      LibC.foo(foo &.to_s)
      ))
  end

  it "allows setting/getting external variable as function pointer" do
    codegen(%(
      require "prelude"

      lib LibC
        $x : ->
      end

      LibC.x = ->{}
      LibC.x.call
      ))
  end

  it "can use enum as fun argument" do
    codegen(%(
      enum Foo
        A
      end

      lib LibC
        fun foo(x : Foo)
      end

      LibC.foo(Foo::A)
      ))
  end

  it "can use enum as fun return" do
    codegen(%(
      enum Foo
        A
      end

      lib LibC
        fun foo : Foo
      end

      LibC.foo
      ))
  end

  it "can use tuple as fun return" do
    test_c(
      %(
        struct s {
          int x;
          int y;
        };

        struct s foo() {
          struct s a = {1, 2};
          return a;
        }
      ),
      %(
        lib LibFoo
          fun foo : {Int32, Int32}
        end

        tuple = LibFoo.foo
        tuple[0] + tuple[1]
      ), &.to_i.should eq(3))
  end

  it "get fun field from struct (#672)" do
    run(%(
      require "prelude"

      lib Moo
        struct Type
          func : (Type*) -> Int32
        end
      end

      p = Pointer(Moo::Type).malloc(1)
      p.value.func = -> (t: Moo::Type*) { 10 }
      p.value.func.call(p)
      )).to_i.should eq(10)
  end

  it "get fun field from union (#672)" do
    run(%(
      require "prelude"

      lib Moo
        union Type
          func : (Type*) -> Int32
        end
      end

      p = Pointer(Moo::Type).malloc(1)
      p.value.func = -> (t: Moo::Type*) { 10 }
      p.value.func.call(p)
      )).to_i.should eq(10)
  end

  it "refers to lib type (#960)" do
    codegen(%(
      lib Thing
      end

      Thing
      ))
  end

  it "allows invoking out with underscore " do
    codegen(%(
      lib Lib
        fun foo(x : Int32*) : Float64
      end

      Lib.foo out _
      ))
  end

  it "passes int as another float type in literal" do
    codegen(%(
      lib LibFoo
        fun foo(x : Int32)
      end

      LibFoo.foo 1234.5
      ))
  end

  it "passes nil to varargs (#1570)" do
    codegen(%(
      lib LibFoo
        fun foo(...)
      end

      LibFoo.foo(nil)
      ))
  end

  it "casts C fun to Crystal proc when accessing instance var (#2515)" do
    codegen(%(
      require "prelude"

      lib LibFoo
        struct Some
          x : ->
        end
      end

      LibFoo::Some.new.to_s
      ))
  end

  it "doesn't crash when casting -1 to UInt32 (#3594)" do
    codegen(%(
      lib LibFoo
        fun foo(x : UInt32) : Nil
      end

      LibFoo.foo(-1)
      ))
  end

  it "doesn't crash with nil and varargs (#4414)" do
    codegen(%(
      lib LibFoo
        fun foo(Void*, ...)
      end

      x = nil
      LibFoo.foo(x)
      ))
  end
end
