require "../../spec_helper"

describe "Codegen: const" do
  it "define a constant" do
    run("CONST = 1; CONST").to_i.should eq(1)
  end

  it "support nested constant" do
    run("class Foo; A = 1; end; Foo::A").to_i.should eq(1)
  end

  it "support constant inside a def" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        A = 1

        def foo
          A
        end
      end

      Foo.new.foo
      CRYSTAL
  end

  it "finds nearest constant first" do
    run(<<-CRYSTAL).to_f32.should eq(2.5)
      CONST = 1

      class Foo
        CONST = 2.5_f32

        def foo
          CONST
        end
      end

      Foo.new.foo
      CRYSTAL
  end

  it "allows constants with same name" do
    run(<<-CRYSTAL).to_f32.should eq(2.5)
      CONST = 1

      class Foo
        CONST = 2.5_f32

        def foo
          CONST
        end
      end

      CONST
      Foo.new.foo
      CRYSTAL
  end

  it "constants with expression" do
    run(<<-CRYSTAL).to_i.should eq(2)
      CONST = 1 + 1
      CONST
      CRYSTAL
  end

  it "finds global constant" do
    run(<<-CRYSTAL).to_i.should eq(1)
      CONST = 1

      class Foo
        def foo
          CONST
        end
      end

      Foo.new.foo
      CRYSTAL
  end

  it "define a constant in lib" do
    run("lib LibFoo; A = 1; end; LibFoo::A").to_i.should eq(1)
  end

  it "invokes block in const" do
    run("require \"prelude\"; CONST = [\"1\"].map { |x| x.to_i }; CONST[0]").to_i.should eq(1)
  end

  it "declare constants in right order" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "prelude"

      CONST1 = 1 + 1
      CONST2 = true ? CONST1 : 0
      CONST2
      CRYSTAL
  end

  it "uses correct types lookup" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      module Moo
        class B
          def foo
            1
          end
        end

        C = B.new;
      end

      def foo
        Moo::C.foo
      end

      foo
      CRYSTAL
  end

  it "codegens variable assignment in const" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      CONST = begin
            f = Foo.new(1)
            f
          end

      def foo
        CONST.x
      end

      foo
      CRYSTAL
  end

  it "declaring var" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      BAR = begin
        a = 1
        while 1 == 2
          b = 2
        end
        a
      end
      class Foo
        def compile
          BAR
        end
      end

      Foo.new.compile
      CRYSTAL
  end

  it "initialize const that might raise an exception" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"
      CONST = (raise "OH NO" if 1 == 2)

      def doit
        CONST
      rescue
      end

      doit.nil?
      CRYSTAL
  end

  it "allows implicit self in constant, called from another class (bug)" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      module Foo
        def self.foo
          1
        end

        A = foo
      end

      class Bar
        def bar
          Foo::A
        end
      end

      Bar.new.bar
      CRYSTAL
  end

  it "codegens two consts with same variable name" do
    run(<<-CRYSTAL).to_i.should eq(3)
      require "prelude"

      CONST1 = begin
            a = 1
          end

      CONST2 = begin
            a = 2.3
          end

      (CONST1 + CONST2).to_i
      CRYSTAL
  end

  it "works with variable declared inside if" do
    run(<<-CRYSTAL).to_i.should eq(4)
      require "prelude"

      FOO = begin
        if 1 == 2
          x = 3
        else
          x = 4
        end
        x
      end
      FOO
      CRYSTAL
  end

  it "codegens constant that refers to another constant that is a struct" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"

      struct Foo
        X = Foo.new(1)
        Y = X

        def initialize(@value : Int32)
        end

        def value
          @value
        end
      end

      Foo::Y.value
      CRYSTAL
  end

  it "codegens constant that is declared later because of virtual dispatch" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Base
        def base
        end
      end

      class Base2 < Base
        def base
        end
      end

      b = Base.new || Base2.new
      b.base

      class MyBase < Base
        CONST = 1

        def base
          CONST
        end
      end

      MyBase.new.base
      CRYSTAL
  end

  it "doesn't crash if constant is used, but class is never instantiated (#1106)" do
    codegen(<<-CRYSTAL)
      require "prelude"

      class Foo
        BAR = 1 || 2

        def foo
          BAR
        end
      end

      ->(x : Foo) { x.foo }
      CRYSTAL
  end

  it "uses const before declaring it (hoisting)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      require "prelude"

      x = CONST

      CONST = foo

      def foo
        a = 1
        b = 2
        a &+ b
      end

      x
      CRYSTAL
  end

  it "uses const before declaring it in another module" do
    run(<<-CRYSTAL).to_i.should eq(3)
      require "prelude"

      def foo
        a = 1
        b = 2
        a + b
      end

      class Foo
        def self.foo
          CONST
        end
      end

      x = Foo.foo

      CONST = foo

      x
      CRYSTAL
  end

  it "initializes simple const" do
    run(<<-CRYSTAL).to_i.should eq(10)
      FOO = 10
      FOO
      CRYSTAL
  end

  it "initializes simple const via another const" do
    run(<<-CRYSTAL).to_i.should eq(10)
      BAR = 10
      FOO = BAR
      FOO
      CRYSTAL
  end

  it "initializes ARGC_UNSAFE" do
    run(<<-CRYSTAL).to_i.should eq(0)
      ARGC_UNSAFE
      CRYSTAL
  end

  it "gets pointerof constant" do
    run(<<-CRYSTAL).to_i.should eq(10)
      require "prelude"

      z = pointerof(FOO).value
      FOO = 10
      z
      CRYSTAL
  end

  it "gets pointerof complex constant" do
    run(<<-CRYSTAL).to_i.should eq(10)
      require "prelude"

      z = pointerof(FOO).value
      FOO = begin
        a = 10
        a
      end
      z
      CRYSTAL
  end

  it "gets pointerof constant inside class" do
    run(<<-CRYSTAL).to_i.should eq(42)
      require "prelude"

      class Foo
        BAR = 42

        @z : Int32

        def initialize
          @z = pointerof(BAR).value
        end

        def z
          @z
        end
      end

      Foo.new.z
      CRYSTAL
  end

  it "inlines simple const" do
    mod = codegen(<<-CRYSTAL)
      CONST = 1
      CONST
      CRYSTAL

    mod.to_s.should_not contain("CONST")
  end

  it "inlines enum value" do
    mod = codegen(<<-CRYSTAL)
      enum Foo
        CONST
      end

      Foo::CONST
      CRYSTAL

    mod.to_s.should_not contain("CONST")
  end

  it "inlines const with math" do
    mod = codegen(<<-CRYSTAL)
      struct Int32
        def //(other)
          self
        end
      end

      CONST = (((1 + 2) * 3 &+ 1 &* 3 &- 2) // 2) + 42000
      CONST
      CRYSTAL
    mod.to_s.should_not contain("CONST")
    mod.to_s.should contain("42005")
  end

  it "inlines const referencing another const" do
    mod = codegen(<<-CRYSTAL)
      OTHER = 1

      CONST = OTHER
      CONST
      CRYSTAL

    mod.to_s.should_not contain("CONST")
    mod.to_s.should_not contain("OTHER")
  end

  it "inlines bool const" do
    mod = codegen(<<-CRYSTAL)
      CONST = true
      CONST
      CRYSTAL

    mod.to_s.should_not contain("CONST")
  end

  it "inlines char const" do
    mod = codegen(<<-CRYSTAL)
      CONST = 'a'
      CONST
      CRYSTAL

    mod.to_s.should_not contain("CONST")
  end

  it "synchronizes initialization of constants" do
    run(<<-CRYSTAL).to_b.should be_true
      require "prelude"

      def foo
        v1, v2 = 1, 1
        rand(100000..10000000).times do
          v1, v2 = v2, v1 &+ v2
        end
        v2
      end

      ch = Channel(Int32).new

      10.times do
        spawn do
          ch.send X
        end
      end

      X = foo

      def test(ch)
        expected = X

        10.times do
          if ch.receive != expected
            return false
          end
        end

        true
      end

      test(ch)
      CRYSTAL
  end

  it "runs const side effects (#8862)" do
    run(<<-CRYSTAL).to_i.should eq(6)
      require "prelude"

      class Foo
        @@x = 0

        def self.set
          @@x = 3
        end

        def self.x
          @@x
        end
      end

      a = HELLO

      HELLO = begin
        Foo.set
        1 &+ 2
      end

      a &+ Foo.x
      CRYSTAL
  end

  it "supports closured vars inside initializers (#10474)" do
    run(<<-CRYSTAL).to_i.should eq(3)
      class Foo
        def bar
          3
        end
      end

      def func(&block : -> Int32)
        block.call
      end

      CONST = begin
        foo = Foo.new
        func do
          foo.bar
        end
      end

      CONST
      CRYSTAL
  end

  it "supports storing function returning nil" do
    run(<<-CRYSTAL).to_b.should be_true
      def foo
        "foo"
        nil
      end

      CONST = foo
      CONST.nil?
      CRYSTAL
  end
end
