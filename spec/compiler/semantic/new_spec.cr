require "../../spec_helper"

describe "Semantic: new" do
  it "doesn't incorrectly redefines new for generic class" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo(T)
        def self.new
          1
        end
      end

      Foo(Int32).new
      CRYSTAL
  end

  it "evaluates initialize default value at the instance scope (1) (#731)" do
    assert_type(<<-CRYSTAL) { types["Foo"] }
      class Foo
        def initialize(@x = self)
        end

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "evaluates initialize default value at the instance scope (2) (#731)" do
    assert_type(<<-CRYSTAL) { char }
      class Foo
        def initialize(@x = self, @y = 'a')
        end

        def y
          @y
        end
      end

      Foo.new(y: 'b').y
      CRYSTAL
  end

  it "evaluates initialize default value at the instance scope (3) (#731)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        @x : Int32

        def initialize(@x = bar)
          yield 1, 2
        end

        def x
          @x
        end

        def bar
          1
        end
      end

      foo = Foo.new do |x, y|
      end
      foo.x
      CRYSTAL
  end

  it "evaluates initialize default value at the instance scope (4) (#731)" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        @x : Int32

        def initialize(@x = bar, &@block : ->)
        end

        def x
          @x
        end

        def bar
          1
        end
      end

      foo = Foo.new do
      end
      foo.x
      CRYSTAL
  end

  it "evaluates initialize default value at the instance scope (5) (#731)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      class Foo(R)
        @x : Int32

        def initialize(@x = bar, &@block : -> R)
        end

        def bar
          10
        end

        def r
          @block.call
        end
      end

      Foo.new { 1 }.r
      CRYSTAL
  end

  it "evaluates initialize default value at the instance scope (6) (#731)" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
      class Foo(R)
        @x : Int32

        def initialize(@x = bar, &@block : -> R)
        end

        def bar
          10
        end

        def r
          @block.call
        end
      end

      Foo(Int32).new { 1 }.r
      CRYSTAL
  end

  it "errors if using self call in default argument (1)" do
    assert_error <<-CRYSTAL, "this 'initialize' doesn't explicitly initialize instance variable '@caps' of My"
      class My
        @name : String
        @caps : String

        def initialize(@name, caps = self.name)
          x = caps
          @caps = x
        end

        def name
          @name
        end
      end

      My.new("foo")
      CRYSTAL
  end

  it "errors if using self call in default argument (2)" do
    assert_error <<-CRYSTAL, "this 'initialize' doesn't explicitly initialize instance variable '@caps' of My"
      class My
        @name : String
        @caps : String

        def initialize(@name, caps = self.name)
          @caps = caps
        end

        def name
          @name
        end
      end

      My.new("foo")
      CRYSTAL
  end

  it "errors if using self call in default argument (3)" do
    assert_error <<-CRYSTAL, "this 'initialize' doesn't explicitly initialize instance variable '@caps' of My"
      class My
        @name : String
        @caps : String

        def initialize(@name, @caps = self.name)
        end

        def name
          @name
        end
      end

      My.new("foo")
      CRYSTAL
  end

  it "inherits initialize and new methods if doesn't define new (#3238)" do
    assert_type(<<-CRYSTAL) { types["Bar"] }
      class Foo(T)
        def initialize(x : Int32)
        end

        def self.new(x : Char)
          new(1)
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new('a')
      CRYSTAL
  end

  it "doesn't have default new for inherited class from generic type" do
    assert_error <<-CRYSTAL, "wrong number of arguments for 'Bar.new' (given 0, expected 1)"
      class Foo(T)
        def initialize(x : Int32)
        end
      end

      class Bar < Foo(Int32)
      end

      Bar.new
      CRYSTAL
  end

  it "uses correct receiver for `initialize` in namespaced generic classes (#4086)" do
    assert_type <<-CRYSTAL { char }
      class Foo
        class Baz(T)
        end

        module Bar
          class Baz(T) < Foo
            def initialize(x)
            end

            def foo
              'a'
            end
          end
        end
      end

      Foo::Bar::Baz(Int32).new(1).foo
      CRYSTAL
  end

  it "looks up the restrictions of an inherited initialize in its namespace" do
    assert_type <<-CRYSTAL { types["Bar"] }
      module Foo
        class Rule
        end

        class Base(T)
          def initialize(rules : Array(Rule), value : T)
          end
        end
      end

      class Bar < Foo::Base(Int32)
      end

      Bar.new([] of Foo::Rule, 1)
      CRYSTAL
  end

  it "looks up the restrictions of an inherited initialize in its namespace for a generic subclass" do
    assert_type <<-CRYSTAL { generic_class "Bar", int32 }
      module Foo
        class Rule
        end

        class Base(T)
          def initialize(rules : Array(Rule))
          end
        end
      end

      class Bar(U) < Foo::Base(U)
      end

      Bar(Int32).new([] of Foo::Rule)
      CRYSTAL
  end

  it "looks up the restrictions of an inherited self.new in its namespace" do
    assert_type <<-CRYSTAL { types["Bar"] }
      module Foo
        class Rule
        end

        class Base(T)
          def self.new(rule : Rule, value : Int32)
            new
          end
        end
      end

      class Bar < Foo::Base(Int32)
      end

      Bar.new(Foo::Rule.new, 1)
      CRYSTAL
  end

  it "doesn't let a type in the subclass' namespace shadow an inherited initialize's restriction" do
    assert_error <<-CRYSTAL, "expected argument #1 to 'Bar.new' to be Foo::Rule, not Rule"
      class Rule
      end

      module Foo
        class Rule
        end

        class Base(T)
          def initialize(rule : Rule)
          end
        end
      end

      class Bar < Foo::Base(Int32)
      end

      Bar.new(Rule.new)
      CRYSTAL
  end
end
