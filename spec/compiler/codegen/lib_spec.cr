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
    build("
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
    build(%(
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
    build(%(
      require "prelude"

      lib LibC
        $x : ->
      end

      LibC.x = ->{}
      LibC.x.call
      ))
  end

  it "can use enum as fun argument" do
    build(%(
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
    build(%(
      enum Foo
        A
      end

      lib LibC
        fun foo : Foo
      end

      LibC.foo
      ))
  end
end
