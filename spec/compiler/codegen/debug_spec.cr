require "../../spec_helper"

describe "Code gen: debug" do
  it "codegens abstract struct (#3578)" do
    codegen(%(
      abstract struct Base
      end

      struct Foo < Base
      end

      struct Bar < Base
      end

      x = Foo.new || Bar.new
      ), debug: Crystal::Debug::All)
  end

  it "codegens lib union (#7335)" do
    codegen <<-CRYSTAL, debug: Crystal::Debug::All
      lib Foo
        union Bar
          a : Int32
          b : Int16
          c : Int8
        end
      end

      x = Foo::Bar.new
      CRYSTAL
  end

  it "codegens extern union (#7335)" do
    codegen <<-CRYSTAL, debug: Crystal::Debug::All
      @[Extern(union: true)]
      struct Foo
        @a = uninitialized Int32
        @b = uninitialized Int16
        @c = uninitialized Int8
      end

      x = Foo.new
      CRYSTAL
  end

  it "inlines instance var access through getter in debug mode" do
    run(%(
      struct Bar
        @x = 1

        def set
          @x = 2
        end

        def x
          @x
        end
      end

      class Foo
        @bar = Bar.new

        def set
          bar.set
        end

        def bar
          @bar
        end
      end

      foo = Foo.new
      foo.set
      foo.bar.x
      ), debug: Crystal::Debug::All, filename: "foo.cr").to_i.should eq(2)
  end

  it "codegens correct debug info for untyped expression (#4007 and #4008)" do
    codegen(%(
      require "prelude"

      int = 3
      case int
      when 0
          puts 0
      when 1, 2, Int32
          puts "1 | 2 | Int32"
      else
          puts int
      end
      ), debug: Crystal::Debug::All)
  end

  it "codegens correct debug info for new with custom allocate (#3945)" do
    codegen(%(
      class Foo
        def initialize
        end

        def self.allocate
          Pointer(UInt8).malloc(1_u64).as(self)
        end
      end

      Foo.new
      ), debug: Crystal::Debug::All)
  end

  it "correctly restores debug location after fun change (#4254)" do
    codegen(%(
      require "prelude"

      class Foo
        def self.one
          TWO.two { three }
          self
        end

        def self.three
          1 + 2
        end

        def two(&block)
          block
        end
      end

      ONE = Foo.one
      TWO = Foo.new

      ONE.three
      ), debug: Crystal::Debug::All)
  end

  it "has correct debug location after constant initialization in call with block (#4719)" do
    codegen(%(
      require "prelude"

      fun __crystal_malloc_atomic(size : UInt32) : Void*
        x = uninitialized Void*
        x
      end

      class Foo
      end

      class Bar
        def initialize
          yield
        end
      end

      A = Foo.new

      Bar.new { }

      A
      ), debug: Crystal::Debug::All)
  end

  it "has debug info in closure inside if (#5593)" do
    codegen(%(
      require "prelude"

      def foo
        if true && true
          yield 1
        end
      end

      def bar(&block)
        block
      end

      foo do |i|
        bar do
          i
        end
      end
      ), debug: Crystal::Debug::All)
  end

  it "doesn't emit incorrect debug info for closured self" do
    codegen(%(
      def foo(&block : Int32 ->)
        block.call(1)
      end

      class Foo
        def bar
          foo do
            self
          end
        end
      end

      Foo.new.bar
      ), debug: Crystal::Debug::All)
  end

  it "doesn't emit debug info for unused variable declarations (#9882)" do
    codegen(%(
      x : Int32
      ), debug: Crystal::Debug::All)
  end

  it "stores and restores debug location after jumping to main (#6920)" do
    codegen(%(
      require "prelude"

      Module.method

      module Module
        def self.value
          1 &+ 2
        end

        @@x : Int32 = value

        def self.method
          @@x
        end
      end
      ), debug: Crystal::Debug::All)
  end

  it "stores and restores debug location after jumping to main (2)" do
    codegen(%(
      module Foo
        @@x : Int32 = begin
          y = 1
        end

        def self.x
          @@x
        end
      end

      Foo.x
      ), debug: Crystal::Debug::All)
  end

  it "stores and restores debug location after jumping to main (3)" do
    codegen(%(
      def raise(exception)
        x = uninitialized NoReturn
        x
      end

      lib LibFoo
        $foo : ->
      end

      LibFoo.foo = ->{ }
      ), debug: Crystal::Debug::All)
  end

  it "doesn't fail on constant read calls (#11416)" do
    codegen(%(
      require "prelude"

      class Foo
        def foo
        end
      end

      def a_foo
        Foo.new
      end

      THE_FOO.foo

      THE_FOO = a_foo
      ), debug: Crystal::Debug::All)
  end

  it "doesn't fail on splat expansions inside array-like literals" do
    run(%(
      require "prelude"

      class Foo
        def each
          yield 1
          yield 2
          yield 3
        end
      end

      class Bar
        @bar = 0

        def <<(value)
          @bar = @bar &* 10 &+ value
        end

        def bar
          @bar
        end
      end

      x = Foo.new
      y = Bar{*x}
      y.bar
      ), debug: Crystal::Debug::All).to_i.should eq(123)
  end
end
