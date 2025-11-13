{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "structs" do
    it "does allocate, set instance var and get instance var" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          @x = 0_i64
          @y = 0_i64

          def x=(@x)
          end

          def x
            @x
          end

          def y=(@y)
          end

          def y
            @y
          end
        end

        foo = Foo.allocate
        foo.x = 22_i64
        foo.y = 20_i64
        foo.x + foo.y
      CRYSTAL
    end

    it "does constructor" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end
        end

        foo = Foo.new(42)
        foo.x
      CRYSTAL
    end

    it "interprets read instance var of struct" do
      interpret(<<-CRYSTAL).should eq(20)
        struct Foo
          @x = 0_i64
          @y = 0_i64

          def y=(@y)
          end

          def y
            @y
          end
        end

        foo = Foo.allocate
        foo.y = 20_i64
        foo.@y
      CRYSTAL
    end

    it "casts def body to def type" do
      interpret(<<-CRYSTAL).should eq(1)
        struct Foo
          def foo
            return nil if 1 == 2

            self
          end
        end

        value = Foo.new.foo
        value ? 1 : 2
      CRYSTAL
    end

    it "discards allocate" do
      interpret(<<-CRYSTAL).should eq(3)
        struct Foo
        end

        Foo.allocate
        3
      CRYSTAL
    end

    it "mutates struct inside union" do
      interpret(<<-CRYSTAL).should eq(2)
        struct Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end
        end

        foo = 1 == 1 ? Foo.new : nil
        if foo
          foo.inc
        end

        if foo
          foo.x
        else
          0
        end
      CRYSTAL
    end

    it "mutates struct stored in class var" do
      interpret(<<-CRYSTAL).should eq(3)
        struct Foo
          def initialize
            @x = 1
          end

          def inc
            @x += 1
          end

          def x
            @x
          end
        end

        module Moo
          @@foo = Foo.new

          def self.mutate
            @@foo.inc
          end

          def self.foo
            @@foo
          end
        end

        before = Moo.foo.x
        Moo.mutate
        after = Moo.foo.x
        before + after
      CRYSTAL
    end

    it "does simple class instance var initializer" do
      interpret(<<-CRYSTAL).should eq(42)
        class Foo
          @x = 42

          def x
            @x
          end
        end

        foo = Foo.allocate
        foo.x
      CRYSTAL
    end

    it "does complex class instance var initializer" do
      interpret(<<-CRYSTAL).should eq(42)
        class Foo
          @x : Int32 = begin
            a = 20
            b = 22
            a + b
          end

          def x
            @x
          end
        end

        foo = Foo.allocate
        foo.x
      CRYSTAL
    end

    it "does class instance var initializer inheritance" do
      interpret(<<-CRYSTAL).should eq(6)
        module Moo
          @z = 3

          def z
            @z
          end
        end

        class Foo
          include Moo

          @x = 1

          def x
            @x
          end
        end

        class Bar < Foo
          @y = 2

          def y
            @y
          end
        end

        bar = Bar.allocate
        bar.x + bar.y + bar.z
      CRYSTAL
    end

    it "does simple struct instance var initializer" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          @x = 42

          def x
            @x
          end
        end

        foo = Foo.allocate
        foo.x
      CRYSTAL
    end

    it "does call receiver by value from VirtualType abstract struct to concrete struct (#12190)" do
      interpret(<<-CRYSTAL).should eq(42)
        abstract struct Base
        end

        struct A < Base
          def initialize(@x : Int32)
          end

          def foo
            @x
          end
        end

        struct B < Base
        end

        v = A.new(42) || B.new

        if v.is_a?(A)
          v.foo
        else
          1
        end
      CRYSTAL
    end

    it "does call receiver by value from VirtualType abstract struct to union" do
      interpret(<<-CRYSTAL).should eq(42)
        abstract struct Base
        end

        struct A < Base
          def initialize(@x : Int32)
          end

          def foo
            @x
          end
        end

        struct B < Base
          def initialize(@x : Int32)
          end

          def foo
            @x
          end
        end

        struct C < Base
        end

        v = A.new(42) || B.new(3)

        if v.is_a?(A | B)
          v.foo
        else
          1
        end
      CRYSTAL
    end

    it "sets multiple instance vars in virtual abstract struct call (#12187)" do
      interpret(<<-CRYSTAL).should eq(6)
        abstract struct Foo
          @x = 0
          @y = 0
          @z = 0

          def set
            @x = 1
            @y = 2
            @z = 3
          end

          def x
            @x
          end

          def y
            @y
          end

          def z
            @z
          end
        end

        struct Bar < Foo
        end

        struct Baz < Foo
        end

        f = Bar.new || Baz.new
        f.set
        f.x + f.y + f.z
      CRYSTAL
    end

    it "inlines struct method that returns self (#12253)" do
      interpret(<<-CRYSTAL).should eq(42)
        struct Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end

          def foo
            me
          end

          def me
            self
          end
        end

        a = Foo.new(42)
        b = a.foo
        b.x
      CRYSTAL
    end
  end
end
