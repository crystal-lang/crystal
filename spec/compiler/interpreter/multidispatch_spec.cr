{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "multidispatch" do
    it "does dispatch on one argument" do
      interpret(<<-CRYSTAL).should eq(42)
        def foo(x : Char)
          x.ord.to_i32
        end

        def foo(x : Int32)
          x
        end

        a = 42 || 'a'
        foo(a)
      CRYSTAL
    end

    it "does dispatch on one argument inside module with implicit self" do
      interpret(<<-CRYSTAL).should eq(42)
        module Moo
          def self.foo(x : Char)
            x.ord.to_i32
          end

          def self.foo(x : Int32)
            x
          end

          def self.bar
            a = 42 || 'a'
            foo(a)
          end
        end

        Moo.bar
      CRYSTAL
    end

    it "does dispatch on one argument inside module with explicit receiver" do
      interpret(<<-CRYSTAL).should eq(42)
        module Moo
          def self.foo(x : Char)
            x.ord.to_i32
          end

          def self.foo(x : Int32)
            x
          end

          def self.bar
          end
        end

        a = 42 || 'a'
        Moo.foo(a)
      CRYSTAL
    end

    it "does dispatch on receiver type" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Char
          def foo
            self.ord.to_i32
          end
        end

        struct Int32
          def foo
            self
          end
        end

        a = 42 || 'a'
        a.foo
      CRYSTAL
    end

    it "does dispatch on receiver type and argument type" do
      interpret(<<-CRYSTAL).should eq(42 + 'b'.ord)
        struct Char
          def foo(x : Int32)
            self.ord.to_i32 + x
          end

          def foo(x : Char)
            self.ord.to_i32 + x.ord.to_i32
          end
        end

        struct Int32
          def foo(x : Int32)
            self + x
          end

          def foo(x : Char)
            self + x.ord.to_i32
          end
        end

        a = 42 || 'a'
        b = 'b' || 43
        a.foo(b)
      CRYSTAL
    end

    it "does dispatch on receiver type and argument type, multiple times" do
      interpret(<<-CRYSTAL).should eq(2 * (42 + 'b'.ord))
        struct Char
          def foo(x : Int32)
            self.ord.to_i32 + x
          end

          def foo(x : Char)
            self.ord.to_i32 + x.ord.to_i32
          end
        end

        struct Int32
          def foo(x : Int32)
            self + x
          end

          def foo(x : Char)
            self + x.ord.to_i32
          end
        end

        a = 42 || 'a'
        b = 'b' || 43
        x = a.foo(b)
        y = a.foo(b)
        x + y
      CRYSTAL
    end

    it "does dispatch on one argument with struct receiver, and modifies it" do
      interpret(<<-CRYSTAL).should eq(32)
        struct Foo
          def initialize
            @x = 2_i64
          end

          def foo(x : Int32)
            v = @x + x
            @x = 10_i64
            v
          end

          def foo(x : Char)
            v = @x + x.ord.to_i32
            @x = 30_i64
            v
          end

          def x
            @x
          end
        end

        foo = Foo.new

        a = 20 || 'a'
        b = foo.foo(a)
        b + foo.x
      CRYSTAL
    end

    it "downcasts self from union to struct (pass pointer to self)" do
      interpret(<<-CRYSTAL).should eq(2)
        class Foo
          def initialize
            @x = 1_i64
          end

          def x
            @x
          end
        end

        struct Point
          def initialize
            @x = 2_i64
          end

          def x
            @x
          end
        end

        obj = Point.new || Foo.new
        obj.x
      CRYSTAL
    end

    it "does dispatch on virtual type" do
      interpret(<<-CRYSTAL).should eq(4)
        abstract class Foo
          def foo
            1
          end
        end

        class Bar < Foo
        end

        class Baz < Foo
          def foo
            3
          end
        end

        class Qux < Foo
        end

        foo = Bar.new || Baz.new
        x = foo.foo

        foo = Baz.new || Bar.new
        y = foo.foo

        x + y
      CRYSTAL
    end

    it "does dispatch on one argument with block" do
      interpret(<<-CRYSTAL).should eq(42)
        def foo(x : Char)
          yield x.ord.to_i32
        end

        def foo(x : Int32)
          yield x
        end

        a = 32 || 'a'
        foo(a) do |x|
          x + 10
        end
      CRYSTAL
    end

    it "doesn't compile block if it's not used (no yield)" do
      interpret(<<-CRYSTAL).should eq(2)
        class Object
          def try
            yield self
          end
        end

        struct Nil
          def try(&)
            self
          end
        end

        a = 1 || nil
        b = a.try { |x| x + 1 }
        b || 10
      CRYSTAL
    end

    it "does multidispatch on virtual metaclass type (1)" do
      interpret(<<-CRYSTAL).should eq("BB")
        class Class
          def lt(other : T.class) : String forall T
            {% @type %}
            other.gt(self)
          end

          def gt(other : T.class) forall T
            {{ @type.stringify + T.stringify }}
          end
        end

        class A
        end

        class B < A
        end

        t = B || A
        t.lt(t)
      CRYSTAL
    end

    it "does multidispatch on virtual metaclass type (2)" do
      interpret(<<-CRYSTAL).should eq("BB")
        class Class
          def lt(other : T.class) : String forall T
            {% @type %}
            other.gt(self)
          end

          def gt(other : T.class) forall T
            {{ @type.stringify + T.stringify }}
          end
        end

        class A
        end

        class B < A
        end

        class C < B
        end

        t = B || A
        t.lt(t)
      CRYSTAL
    end

    it "passes self as pointer when doing multidispatch" do
      interpret(<<-CRYSTAL).should eq(10)
        struct Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        struct Bar
          def initialize(@x : Int32)
          end

          def x
            @x
          end

          def to_unsafe
            pointerof(@x)
          end
        end

        foo = Foo.new(0) || Bar.new(1)
        foo.to_unsafe.value = 10
        foo.x
      CRYSTAL
    end

    it "passes self as pointer when doing multidispatch (2)" do
      interpret(<<-CRYSTAL).should be_true
        struct Tuple
          def ==(other)
            false
          end
        end

        a = 1.as(Int32 | Tuple(Int64, Int64))
        a == 1
      CRYSTAL
    end

    it "initialize multidispatch" do
      interpret(<<-CRYSTAL).should eq(1)
        struct Foo
          def initialize(x : Int64)
            initialize(x, 1 || 'a')
          end

          def initialize(@x : Int64, y : Int32)
          end

          def initialize(@x : Int64, y : Char)
          end

          def x
            @x
          end
        end

        Foo.new(1_i64).x
      CRYSTAL
    end

    it "does multidispatch with mandatory named arguments" do
      interpret(<<-CRYSTAL).should eq(1)
        class Object
          def foo(obj, *, file = "")
            obj
          end
        end

        ("" || nil).foo 1, file: ""
      CRYSTAL
    end

    it "does multidispatch with captured block (#12217)" do
      interpret(<<-CRYSTAL).should eq(42)
        class A
          def then(&callback : Int32 -> Int32)
            callback.call(70)
          end
        end

        class B < A
          def then(&callback : Int32 -> Int32)
            callback.call(30)
          end
        end

        a = A.new
        b = B.new

        a_value = (a || b).then do |x|
          x + 3
        end

        b_value = (b || a).then do |x|
          x + 1
        end

        a_value - b_value
      CRYSTAL
    end

    it "casts multidispatch argument to the def's arg type" do
      interpret(<<-CRYSTAL)
        def foo(a : String) forall T
        end

        def foo(a)
          a
        end

        foo("b" || nil)
      CRYSTAL
    end
  end
end
