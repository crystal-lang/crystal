require "../../spec_helper"

describe "Code gen: debug" do
  it "codegens abstract struct (#3578)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      abstract struct Base
      end

      struct Foo < Base
      end

      struct Bar < Base
      end

      x = Foo.new || Bar.new
      CRYSTAL
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
    run(<<-CRYSTAL, debug: Crystal::Debug::All, filename: "foo.cr").to_i.should eq(2)
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
      CRYSTAL
  end

  it "codegens correct debug info for untyped expression (#4007 and #4008)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
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
      CRYSTAL
  end

  it "codegens correct debug info for new with custom allocate (#3945)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      class Foo
        def initialize
        end

        def self.allocate
          Pointer(UInt8).malloc(1_u64).as(self)
        end
      end

      Foo.new
      CRYSTAL
  end

  it "correctly restores debug location after fun change (#4254)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
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
      CRYSTAL
  end

  it "has correct debug location after constant initialization in call with block (#4719)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
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
      CRYSTAL
  end

  it "has debug info in closure inside if (#5593)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
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
      CRYSTAL
  end

  it "doesn't emit incorrect debug info for closured self" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
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
      CRYSTAL
  end

  it "doesn't emit debug info for unused variable declarations (#9882)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      x : Int32
      CRYSTAL
  end

  it "stores and restores debug location after jumping to main (#6920)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
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
      CRYSTAL
  end

  it "stores and restores debug location after jumping to main (2)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      module Foo
        @@x : Int32 = begin
          y = 1
        end

        def self.x
          @@x
        end
      end

      Foo.x
      CRYSTAL
  end

  it "stores and restores debug location after jumping to main (3)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
      def raise(exception)
        x = uninitialized NoReturn
        x
      end

      lib LibFoo
        $foo : ->
      end

      LibFoo.foo = ->{ }
      CRYSTAL
  end

  it "doesn't fail on constant read calls (#11416)" do
    codegen(<<-CRYSTAL, debug: Crystal::Debug::All)
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
      CRYSTAL
  end

  it "doesn't fail on splat expansions inside array-like literals" do
    run(<<-CRYSTAL, debug: Crystal::Debug::All).to_i.should eq(123)
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
      CRYSTAL
  end

  {% unless LibLLVM::IS_LT_210 %}
    it "supports 128-bit enumerators" do
      codegen(<<-CRYSTAL, debug: Crystal::Debug::All).to_s.should contain(%(!DIEnumerator(name: "X", value: 1002003004005006007008009)))
        enum Foo : Int128
          X = 1002003004005006007008009_i128
        end

        x = Foo::X
        CRYSTAL
    end
  {% end %}

  it "doesn't fail if no top-level code follows discarded class var initializer (#15970)" do
    codegen <<-CRYSTAL, debug: Crystal::Debug::All
      module Foo
        @@x = 1
      end
      CRYSTAL
  end

  it "doesn't fail if class var initializer is followed by metaclass (#15970)" do
    codegen <<-CRYSTAL, debug: Crystal::Debug::All
      module Foo
        @@x = 1
      end

      Int32
      CRYSTAL
  end
end
