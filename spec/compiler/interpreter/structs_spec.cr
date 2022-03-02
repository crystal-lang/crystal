{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"

describe Crystal::Repl::Interpreter do
  context "structs" do
    it "does allocate, set instance var and get instance var" do
      interpret(<<-CODE).should eq(42)
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
      CODE
    end

    it "does constructor" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          def initialize(@x : Int32)
          end

          def x
            @x
          end
        end

        foo = Foo.new(42)
        foo.x
      CODE
    end

    it "interprets read instance var of struct" do
      interpret(<<-CODE).should eq(20)
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
      CODE
    end

    it "casts def body to def type" do
      interpret(<<-CODE).should eq(1)
        struct Foo
          def foo
            return nil if 1 == 2

            self
          end
        end

        value = Foo.new.foo
        value ? 1 : 2
      CODE
    end

    it "discards allocate" do
      interpret(<<-CODE).should eq(3)
        struct Foo
        end

        Foo.allocate
        3
      CODE
    end

    it "mutates struct inside union" do
      interpret(<<-CODE).should eq(2)
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
      CODE
    end

    it "mutates struct stored in class var" do
      interpret(<<-CODE).should eq(3)
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
      CODE
    end

    it "does simple class instance var initializer" do
      interpret(<<-CODE).should eq(42)
        class Foo
          @x = 42

          def x
            @x
          end
        end

        foo = Foo.allocate
        foo.x
      CODE
    end

    it "does complex class instance var initializer" do
      interpret(<<-CODE).should eq(42)
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
      CODE
    end

    it "does class instance var initializer inheritance" do
      interpret(<<-CODE).should eq(6)
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
      CODE
    end

    it "does simple struct instance var initializer" do
      interpret(<<-CODE).should eq(42)
        struct Foo
          @x = 42

          def x
            @x
          end
        end

        foo = Foo.allocate
        foo.x
      CODE
    end
  end
end
