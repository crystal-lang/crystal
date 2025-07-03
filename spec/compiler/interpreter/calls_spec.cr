{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "calls" do
    it "calls a top-level method without arguments and no local vars" do
      interpret(<<-CRYSTAL).should eq(3)
        def foo
          1 + 2
        end

        foo
        CRYSTAL
    end

    it "calls a top-level method without arguments but with local vars" do
      interpret(<<-CRYSTAL).should eq(3)
        def foo
          x = 1
          y = 2
          x + y
        end

        x = foo
        x
        CRYSTAL
    end

    it "calls a top-level method with two arguments" do
      interpret(<<-CRYSTAL).should eq(3)
        def foo(x, y)
          x + y
        end

        x = foo(1, 2)
        x
        CRYSTAL
    end

    it "interprets call with default values" do
      interpret(<<-CRYSTAL).should eq(3)
        def foo(x = 1, y = 2)
          x + y
        end

        foo
        CRYSTAL
    end

    it "interprets call with named arguments" do
      interpret(<<-CRYSTAL).should eq(-15)
        def foo(x, y)
          x - y
        end

        foo(y: 25, x: 10)
        CRYSTAL
    end

    it "interprets self for primitive types" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Int32
          def foo
            self
          end
        end

        42.foo
        CRYSTAL
    end

    it "interprets explicit self call for primitive types" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Int32
          def foo
            self.bar
          end

          def bar
            self
          end
        end

        42.foo
        CRYSTAL
    end

    it "interprets implicit self call for pointer" do
      interpret(<<-CRYSTAL).should eq(1)
        struct Pointer(T)
          def plus1
            self + 1_i64
          end
        end

        ptr = Pointer(UInt8).malloc(1_u64)
        ptr2 = ptr.plus1
        (ptr2 - ptr)
        CRYSTAL
    end

    it "interprets call with if" do
      interpret(<<-CRYSTAL).should eq(2)
        def foo
          1 == 1 ? 2 : 3
        end

        foo
        CRYSTAL
    end

    it "does call with struct as obj" do
      interpret(<<-CRYSTAL).should eq(3)
        struct Foo
          def initialize(@x : Int64)
          end

          def itself
            self
          end

          def x
            @x + 2_i64
          end
        end

        def foo
          Foo.new(1_i64)
        end

        foo.x
      CRYSTAL
    end

    it "does call with struct as obj (2)" do
      interpret(<<-CRYSTAL).should eq(2)
        struct Foo
          def two
            2
          end
        end

        Foo.new.two
      CRYSTAL
    end

    it "does call on instance var that's a struct, from a class" do
      interpret(<<-CRYSTAL).should eq(10)
        class Foo
          def initialize
            @x = 0_i64
            @y = 0_i64
            @z = 0_i64
            @bar = Bar.new(2)
          end

          def foo
            @bar.mutate
            @bar.x
          end
        end

        struct Bar
          def initialize(@x : Int32)
          end

          def mutate
            @x = 10
          end

          def x
            @x
          end
        end

        Foo.new.foo
      CRYSTAL
    end

    it "does call on instance var that's a struct, from a struct" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @x = 0_i64
            @y = 0_i64
            @z = 0_i64
            @bar = Bar.new(2)
          end

          def foo
            @bar.mutate
            @bar.x
          end
        end

        struct Bar
          def initialize(@x : Int32)
          end

          def mutate
            @x = 10
          end

          def x
            @x
          end
        end

        Foo.new.foo
      CRYSTAL
    end

    it "discards call with struct as obj" do
      interpret(<<-CRYSTAL).should eq(4)
        struct Foo
          def initialize(@x : Int64)
          end

          def itself
            self
          end

          def x
            @x + 2_i64
          end
        end

        def foo
          Foo.new(1_i64)
        end

        foo.x
        4
      CRYSTAL
    end

    it "does call on constant that's a struct, takes a pointer to instance var" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        CONST = Foo.new
        CONST.to_unsafe.value
      CRYSTAL
    end

    it "does call on constant that's a struct, takes a pointer to instance var, inside if" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        CONST = Foo.new
        c = (1 == 1 ? CONST : CONST).to_unsafe
        c.value
      CRYSTAL
    end

    it "does call on var that's a struct, takes a pointer to instance var, inside if" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        a = Foo.new
        c = (1 == 1 ? a : a).to_unsafe
        c.value
      CRYSTAL
    end

    it "does call on ivar that's a struct, takes a pointer to instance var, inside if" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        struct Bar
          def initialize
            @foo = Foo.new
          end

          def do_it
            c = (1 == 1 ? @foo : @foo).to_unsafe
            c.value
          end
        end

        Bar.new.do_it
      CRYSTAL
    end

    it "does call on self that's a struct, takes a pointer to instance var, inside if" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end

          def do_it
            c = (1 == 1 ? self : self).to_unsafe
            c.value
          end
        end

        Foo.new.do_it
      CRYSTAL
    end

    it "does call on Pointer#value that's a struct, takes a pointer to instance var" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        foo = Foo.new
        ptr = pointerof(foo)
        c = ptr.value.to_unsafe
        c.value
      CRYSTAL
    end

    it "does call on read instance var that's a struct, takes a pointer to instance var" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize
            @x = 42
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        class Bar
          def initialize(@foo : Foo)
          end
        end

        foo = Foo.new
        bar = Bar.new(foo)
        c = bar.@foo.to_unsafe
        c.value
      CRYSTAL
    end

    it "does ReadInstanceVar with wants_struct_pointer" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize
            @x = 1
            @y = 10
            @bar = Bar.new
          end
        end

        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 42
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        entry = Pointer(Foo).malloc(1)
        entry.value = Foo.new
        ptr = entry.value.@bar.to_unsafe
        ptr.value
      CRYSTAL
    end

    it "does Assign var with wants_struct_pointer" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 42
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        bar = Bar.new
        ptr = (x = bar).to_unsafe
        ptr.value
      CRYSTAL
    end

    it "does Assign instance var with wants_struct_pointer" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 42
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        class Foo
          @x : Bar?

          def foo
            bar = Bar.new
            ptr = (@x = bar).to_unsafe
            ptr.value
          end
        end

        Foo.new.foo
      CRYSTAL
    end

    it "does Assign class var with wants_struct_pointer" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 42
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        class Foo
          @@x : Bar?

          def foo
            bar = Bar.new
            ptr = (@@x = bar).to_unsafe
            ptr.value
          end
        end

        Foo.new.foo
      CRYSTAL
    end

    it "inlines method that just reads an instance var" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize
            @x = 1
            @y = 10
            @bar = Bar.new
          end

          def bar
            @bar
          end
        end

        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 42
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        entry = Pointer(Foo).malloc(1)
        entry.value = Foo.new
        ptr = entry.value.bar.to_unsafe
        ptr.value
      CRYSTAL
    end

    it "inlines method that just reads an instance var, but produces side effects of args" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize
            @x = 1
            @y = 10
            @bar = Bar.new
          end

          def bar(x)
            @bar
          end
        end

        struct Bar
          def initialize
            @x = 1
            @y = 2
            @z = 32
          end

          def to_unsafe
            pointerof(@z)
          end
        end

        entry = Pointer(Foo).malloc(1)
        entry.value = Foo.new
        a = 1
        ptr = entry.value.bar(a = 10).to_unsafe
        ptr.value + a
      CRYSTAL
    end

    it "inlines method that just reads an instance var (2)" do
      interpret(<<-CRYSTAL).should eq(2)
        abstract class Abstract
        end

        class Concrete < Abstract
          def initialize(@x : Int32)
          end

          def x
            @x
          end
        end

        original = Concrete.new(2).as(Abstract)
        original.x
      CRYSTAL
    end

    it "puts struct pointer after tuple indexer" do
      interpret(<<-CRYSTAL).should eq(1)
        struct Point
          def initialize(@x : Int64)
          end

          def x
            @x
          end
        end

        a = Point.new(1_u64)
        t = {a}
        t[0].x
      CRYSTAL
    end

    it "mutates call argument" do
      interpret(<<-CRYSTAL).should eq(9000)
        def foo(x)
          if 1 == 0
            x = "hello"
          end

          if x.is_a?(Int32)
            x
          else
            10
          end
        end

        foo 9000
      CRYSTAL
    end

    it "inlines call that returns self" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @x = 0
          end

          def mutate
            @x = 10
          end

          def x
            @x
          end

          def mutate_itself
            itself.mutate
          end

          def itself
            self
          end
        end

        foo = Foo.new
        foo.mutate_itself
        foo.x
      CRYSTAL
    end

    it "inlines call that returns self (2)" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @x = 0
          end

          def mutate
            @x = 10
          end

          def x
            @x
          end

          def mutate_itself
            self.itself.mutate
          end

          def itself
            self
          end
        end

        foo = Foo.new
        foo.mutate_itself
        foo.x
      CRYSTAL
    end

    it "mutates through pointer (1)" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @x = 0
          end

          def ptr
            pointerof(@x)
          end

          def mutate
            @x = 10
            self
          end

          def x
            @x
          end
        end

        def foo
          Foo.allocate
        end

        foo.mutate.ptr.value
      CRYSTAL
    end

    it "mutates through pointer (2)" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @x = 0
          end

          def ptr
            pointerof(@x)
          end

          def mutate
            @x = 10
            self
          end

          def x
            @x
          end
        end

        def foo
          Foo.allocate
        end

        x = foo.mutate.ptr
        x.value
      CRYSTAL
    end

    it "mutates through pointer (3)" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @x = 0
          end

          def mutate
            @x = 10
          end

          def x
            @x
          end
        end

        ptr = Pointer(Foo).malloc(1_u64)
        ptr.value = Foo.new
        ptr.value.mutate
        ptr.value.x
      CRYSTAL
    end

    it "mutates through read instance var" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @bar = Bar.new
          end

          def bar
            @bar
          end
        end

        struct Bar
          def initialize
            @z = 0
          end

          def z=(@z)
          end

          def z
            @z
          end
        end

        foo = Foo.new
        foo.@bar.z = 10
        foo.bar.z
      CRYSTAL
    end

    it "mutates through inlined instance var with receiver" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @bar = Bar.new
          end

          def bar
            @bar
          end
        end

        struct Bar
          def initialize
            @z = 0
          end

          def z=(@z)
          end

          def z
            @z
          end
        end

        foo = Foo.new
        foo.bar.z = 10
        foo.bar.z
      CRYSTAL
    end

    it "mutates through inlined instance var without receiver" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize
            @bar = Bar.new
          end

          def bar
            @bar
          end

          def mutate
            bar.z = 10
          end
        end

        struct Bar
          def initialize
            @z = 0
          end

          def z=(@z)
          end

          def z
            @z
          end
        end

        foo = Foo.new
        foo.mutate
        foo.bar.z
      CRYSTAL
    end
  end
end
