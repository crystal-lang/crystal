require "../../spec_helper"

describe "Type inference: initialize" do
  it "types instance vars as nilable if doesn't invoke super in initialize" do
    node = parse("
      class Foo
        def initialize
          @baz = Baz.new
          @another = 1
        end
      end

      class Bar < Foo
        def initialize
          @another = 2
        end
      end

      class Baz
      end

      foo = Foo.new
      bar = Bar.new
    ")
    result = infer_type node
    mod = result.program
    foo = mod.types["Foo"] as NonGenericClassType
    foo.instance_vars["@baz"].type.should eq(mod.union_of(mod.nil, mod.types["Baz"]))
    foo.instance_vars["@another"].type.should eq(mod.int32)
  end

  it "types instance vars as nilable if doesn't invoke super in initialize with deep subclass" do
    node = parse("
      class Foo
        def initialize
          @baz = Baz.new
          @another = 1
        end
      end

      class Bar < Foo
        def initialize
          super
        end
      end

      class BarBar < Bar
        def initialize
          @another = 2
        end
      end

      class Baz
      end

      foo = Foo.new
      bar = Bar.new
    ")
    result = infer_type node
    mod = result.program
    foo = mod.types["Foo"] as NonGenericClassType
    foo.instance_vars["@baz"].type.should eq(mod.union_of(mod.nil, mod.types["Baz"]))
    foo.instance_vars["@another"].type.should eq(mod.int32)
  end

  it "types instance vars as nilable if doesn't invoke super with default arguments" do
    node = parse("
      class Foo
        def initialize
          @baz = Baz.new
          @another = 1
        end
      end

      class Bar < Foo
        def initialize(x = 1)
          super()
        end
      end

      class Baz
      end

      foo = Foo.new
      bar = Bar.new(1)
    ")
    result = infer_type node
    mod = result.program
    foo = mod.types["Foo"] as NonGenericClassType
    foo.instance_vars["@baz"].type.should eq(mod.types["Baz"])
    foo.instance_vars["@another"].type.should eq(mod.int32)
  end

  it "checks instance vars of included modules" do
    result = assert_type("
      module Lala
        def lala
          @x = 'a'
        end
      end

      class Foo
        include Lala
      end

      class Bar < Foo
        include Lala

        def initialize
          @x = 1
        end
      end

      b = Bar.new
      f = Foo.new
      f.lala
      ") { char }

    mod = result.program

    foo = mod.types["Foo"] as NonGenericClassType
    foo.instance_vars["@x"].type.should eq(mod.union_of(mod.nil, mod.int32, mod.char))

    bar = mod.types["Bar"] as NonGenericClassType
    bar.instance_vars.length.should eq(0)
  end

  it "errors when instance variable never assigned" do
    assert_error %(
      class Foo
        def foo
          @x.foo
        end
      end

      Foo.new.foo
      ), "(@x was never assigned a value)"
  end

  it "errors when instance variable never assigned" do
    assert_error %(
      class Foo
        def initialize
          @barbar = 1
        end
        def foo
          @barbaz.foo
        end
      end

      Foo.new.foo
      ), "(@barbaz was never assigned a value, did you mean @barbar?)"
  end

  it "types instance var as nilable if not always assigned" do
    assert_type(%(
      class Foo
        def initialize
          if 1 == 2
            @x = 1
          end
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { nilable int32 }
  end

  it "types instance var as nilable if assigned in block" do
    assert_type(%(
      def bar
        yield if 1 == 2
      end

      class Foo
        def initialize
          bar do
            @x = 1
          end
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { nilable int32 }
  end

  it "types instance var as not-nilable if assigned in block but previosly assigned" do
    assert_type(%(
      def bar
        yield if 1 == 2
      end

      class Foo
        def initialize
          @x = 1
          bar do
            @x = 2
          end
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "types instance var as nilable if used before assignment" do
    assert_type(%(
      class Foo
        def initialize
          x = @x
          @x = 1
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { nilable int32 }
  end

  it "types instance var as non-nilable if calls super and super defines it" do
    assert_type(%(
      class Parent
        def initialize
          @x = 1
        end
      end

      class Foo < Parent
        def initialize
          super
          @x + 2
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "types instance var as non-nilable if calls super and super defines it, with one level of indirection" do
    assert_type(%(
      class Parent
        def initialize
          @x = 1
        end
      end

      class SubParent < Parent
      end

      class Foo < SubParent
        def initialize
          super
          @x + 2
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "doesn't type instance var as nilable if out" do
    assert_type(%(
      lib C
        fun foo(x : Int32*)
      end

      class Foo
        def initialize
          C.foo(out @x)
          @x + 2
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "types instance var as nilable if used after method call that reads var" do
    assert_type(%(
      class Foo
        def initialize
          foo
          @x = 1
        end

        def foo
          @x
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { nilable int32 }
  end

  it "types instance var as nilable if used after method call that reads var (2)" do
    assert_error %(
      class Bar
        def bar
        end
      end

      class Foo
        def initialize
          my_method
          @x = Bar.new
        end

        def my_method
          @x.bar
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      ), "undefined method 'bar' for Nil"
  end

  it "doesn't type instance var as nilable if used after global method call" do
    assert_type(%(
      def foo
      end

      class Foo
        def initialize
          foo
          @x = 1
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "doesn't type instance var as nilable if used after method call inside typeof" do
    assert_type(%(
      class Foo
        def initialize
          typeof(foo)
          @x = 1
        end

        def foo
          @x
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "doesn't type instance var as nilable if used after method call that doesn't read var" do
    assert_type(%(
      class Foo
        def initialize
          foo
          @x = 1
        end

        def foo
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "types instance var as nilable if used after method call that reads var through other calls" do
    assert_type(%(
      class Foo
        def initialize
          foo
          @x = 1
        end

        def foo
          bar
        end

        def bar
          x = 1 || 1.5
          baz(x)
        end

        def baz(x : Int32)
          @x
        end

        def baz(x : Float64)
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { nilable int32 }
  end

  it "doesn't type instance var as nilable if used after method call that assigns var" do
    assert_type(%(
      class Foo
        def initialize
          foo
          @x = 1
        end

        def foo
          @x = 2
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "finishes when analyzing recursive calls" do
    assert_type(%(
      class Foo
        def initialize
          foo
          @x = 1
        end

        def foo
          bar
        end

        def bar
          foo
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "doesn't type instance var as nilable if not used in method call" do
    assert_type(%(
      class Foo
        def initialize
          foo
          @x = 1
        end

        def foo
          @y
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "types instance var as nilable if used in first of two method calls" do
    assert_type(%(
      class Foo
        def initialize
          foo
          bar
          @x = 1
        end

        def foo
          @x
        end

        def bar
          @y
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { nilable int32 }
  end

  it "doesn't type instance var as nilable if assigned before method call" do
    assert_type(%(
      class Foo
        def initialize
          @x = 1
          foo
          @x = 1
        end

        def foo
          @x
        end

        def x
          @x
        end
      end

      foo = Foo.new
      foo.x
      )) { int32 }
  end

  it "marks instance variable as nilable in initialize if using self in method" do
    assert_type("
      class Foo
        def initialize
          do_something
          @foo = 1
        end

        def foo
          @foo
        end

        def do_something
          Other.new(self)
        end
      end

      class Other
        def initialize(foo)
        end
      end

      Foo.new.foo
      ") { nilable int32 }
  end

  it "doesn't mark instance variable as nilable when using self in super" do
    assert_type("
      class Parent
        def initialize(foo)
        end
      end

      class Foo < Parent
        def initialize
          super(self)
          @foo = 1
        end

        def foo
          @foo
        end
      end

      Foo.new.foo
      ") { int32 }
  end

  it "errors if found matches for initialize but doesn't cover all (bug #204)" do
    assert_error "
      class Foo
        def initialize(x : Int32)
        end
      end

      a = 1 > 0 ? nil : 1
      Foo.new(a)
      ",
      "no overload matches"
  end

  it "doesn't mark instance variable as nilable when using self.class" do
    assert_type("
      class Foo
        def initialize
          self.class.foo
          @foo = 1
        end

        def foo
          @foo
        end

        def self.foo
        end
      end

      Foo.new.foo
      ") { int32 }
  end

  it "doesn't mark instance variable as nilable when using self.class in method" do
    assert_type("
      class Foo
        def initialize
          bar
          @foo = 1
        end

        def bar
          self.class.foo
        end

        def foo
          @foo
        end

        def self.foo
        end
      end

      Foo.new.foo
      ") { int32 }
  end
end
