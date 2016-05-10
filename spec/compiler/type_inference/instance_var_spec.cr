require "../../spec_helper"

describe "Type inference: instance var" do
  it "declares instance var" do
    assert_type(%(
      class Foo
        @x : Int32

        def initialize
          x = 1
          @x = x
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "declares instance var multiple times, last one wins" do
    assert_type(%(
      class Foo
        @x : Int32
        @x : Int32 | Float64

        def initialize
          x = 1
          @x = x
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { union_of(int32, float64) }
  end

  it "doesn't error when redeclaring subclass variable with the same type" do
    assert_type(%(
      class Foo
        @x : Int32

        def initialize
          x = 1
          @x = x
        end

        def x
          @x
        end
      end

      class Bar < Foo
        @x : Int32
      end

      Bar.new.x
      )) { int32 }
  end

  it "errors when redeclaring subclass variable with a different type" do
    assert_error %(
      class Foo
        @x : Int32

        def initialize
          x = 1
          @x = x
        end

        def x
          @x
        end
      end

      class Bar < Foo
        @x : String
      end

      Bar.new.x
      ),
      "instance variable '@x' of Foo, with Bar < Foo, is already declared as Int32"
  end

  it "declares instance var in module, inherits to type" do
    assert_type(%(
      module Moo
        @x : Int32

        def initialize
          x = 1
          @x = x
        end

        def x
          @x
        end
      end

      class Foo
        include Moo
      end

      Foo.new.x
      )) { int32 }
  end

  it "declares instance var in module, inherits to type recursively" do
    assert_type(%(
      module Moo
        @x : Int32

        def initialize
          x = 1
          @x = x
        end

        def x
          @x
        end
      end

      module Moo2
        include Moo
      end

      class Foo
        include Moo2
      end

      Foo.new.x
      )) { int32 }
  end

  it "declares instance var of generic type" do
    assert_type(%(
      class Foo(T)
        @x : T

        def initialize(@x : T)
        end

        def x
          @x
        end
      end

      Foo.new(1).x
      )) { int32 }
  end

  it "declares instance var of generic type through module" do
    assert_type(%(
      module Moo
        @x : Int32

        def initialize
          a = 1
          @x = a
        end

        def x
          @x
        end
      end

      class Foo(T)
        include Moo
      end

      Foo(Float64).new.x
      )) { int32 }
  end

  it "declares instance var of generic type subclass" do
    assert_type(%(
      class Foo(T)
        @x : T

        def initialize(@x)
        end

        def x
          @x
        end
      end

      class Bar(T) < Foo(T)
      end

      Bar(Int32).new(1).x
      )) { int32 }
  end

  it "declares instance var of generic module" do
    assert_type(%(
      module Moo(T)
        @x : T

        def x
          @x
        end
      end

      class Foo(T)
        include Moo(T)

        def initialize
          a = 1
          @x = a
        end
      end

      Foo(Int32).new.x
      )) { int32 }
  end

  it "declares instance var of generic module from non-generic module" do
    assert_type(%(
      module Moo
        @x : Int32

        def x
          @x
        end
      end

      module Moo2(T)
        include Moo
      end

      class Foo(T)
        include Moo2(T)

        def initialize
          a = 1
          @x = a
        end
      end

      Foo(Float64).new.x
      )) { int32 }
  end

  it "infers type from literal" do
    assert_type(%(
      class Foo
        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "infers type from two literals" do
    assert_type(%(
      class Foo
        def initialize
          @x = 1
          @x = 1.5
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { union_of int32, float64 }
  end

  it "infers type from literal outside def" do
    assert_type(%(
      class Foo
        @x = 1

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "infers type from literal outside def with initialize and type restriction" do
    assert_type(%(
      class Foo
        @x : Int32
        @x = 1

        def initialize
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "infers type from lib out (1)" do
    assert_type(%(
      lib LibFoo
        struct Bar
          x : Int32
        end

        fun foo(x : Int32, y : Bar*) : Int32
      end

      class Foo
        def initialize
          LibFoo.foo(1, out @two)
        end

        def two
          @two
        end
      end

      Foo.new.two
      )) { types["LibFoo"].types["Bar"] }
  end

  it "infers type from lib out (2)" do
    assert_type(%(
      lib LibFoo
        fun foo(x : Int32, y : Float64*) : Int32
      end

      class Foo
        def initialize
          @err = LibFoo.foo(1, out @two)
        end

        def two
          @two
        end
      end

      Foo.new.two
      )) { float64 }
  end

  it "infers type from lib out (3)" do
    assert_type(%(
      lib LibFoo
        fun foo(x : Int32, y : Float64*) : Int32
      end

      class Foo
        def initialize
          @err = LibFoo.foo(1, out @two)
        end

        def err
          @err
        end
      end

      Foo.new.err
      )) { int32 }
  end

  it "infers type from uninitialized" do
    assert_type(%(
      class Foo
        def initialize
          @x = uninitialized Int32
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "doesn't infer for subclass if assigns another type (1)" do
    assert_error %(
      class Foo
        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      class Bar < Foo
        def foo
          @x = 1.5
        end
      end

      Bar.new.foo
      ),
      "instance variable '@x' of Foo must be Int32, not Float64"
  end

  it "doesn't infer for subclass if assigns another type (2)" do
    assert_error %(
      class Foo
      end

      class Bar < Foo
        def foo
          @x = 1.5
        end
      end

      class Foo
        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      Bar.new.foo
      ),
      "instance variable '@x' of Foo must be Int32, not Float64"
  end

  it "infers type from included module" do
    assert_type(%(
      module Moo
        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      class Foo
        include Moo
      end

      Foo.new.x
      )) { int32 }
  end

  it "infers type from included module, outside def" do
    assert_type(%(
      module Moo
        @x = 1

        def x
          @x
        end
      end

      class Foo
        include Moo
      end

      Foo.new.x
      )) { int32 }
  end

  it "infers type from included module recursively" do
    assert_type(%(
      module Moo
        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      module Moo2
        include Moo
      end

      class Foo
        include Moo2
      end

      Foo.new.x
      )) { int32 }
  end

  it "infers type for generic class, with literal" do
    assert_type(%(
      class Foo(T)
        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      Foo(Float64).new.x
      )) { int32 }
  end

  it "infers type for generic class, with T.new" do
    assert_type(%(
      class Bar
      end

      class Foo(T)
        def initialize
          @x = T.new
        end

        def x
          @x
        end
      end

      Foo(Bar).new.x
      )) { types["Bar"] }
  end

  it "infers type for generic class, with T.new and literal" do
    assert_type(%(
      class Bar
      end

      class Foo(T)
        def initialize
          @x = T.new
          @x = 1
        end

        def x
          @x
        end
      end

      Foo(Bar).new.x
      )) { union_of types["Bar"], int32 }
  end

  it "infers type for generic class, with lib call" do
    assert_type(%(
      lib LibFoo
        struct Bar
          x : Int32
        end

        fun foo : Bar
      end

      class Foo(T)
        def initialize
          @x = LibFoo.foo
        end

        def x
          @x
        end
      end

      Foo(Float64).new.x
      )) { types["LibFoo"].types["Bar"] }
  end

  it "infers type for generic class, with &&" do
    assert_type(%(
      class Foo
      end

      class Bar
      end

      class Gen(T)
        def initialize
          @x = T.new || Foo.new
        end

        def x
          @x
        end
      end

      Gen(Bar).new.x
      )) { union_of(types["Foo"], types["Bar"]) }
  end

  it "infers type for generic class, with begin" do
    assert_type(%(
      class Foo
      end

      class Gen(T)
        def initialize
          @x = begin
            1
            T.new
          end
        end

        def x
          @x
        end
      end

      Gen(Foo).new.x
      )) { types["Foo"] }
  end

  it "infers type for generic class, with if" do
    assert_type(%(
      class Foo
      end

      class Bar
      end

      class Gen(T)
        def initialize
          @x = 1 == 2 ? T.new : Foo.new
        end

        def x
          @x
        end
      end

      Gen(Bar).new.x
      )) { union_of(types["Foo"], types["Bar"]) }
  end

  it "infers type for generic class, with case" do
    assert_type(%(
      class Object
        def ===(other)
          self == other
        end
      end

      class Foo
      end

      class Bar
      end

      class Gen(T)
        def initialize
          @x = case 1
               when 2 then T.new
               else Foo.new
               end
        end

        def x
          @x
        end
      end

      Gen(Bar).new.x
      )) { union_of(types["Foo"], types["Bar"]) }
  end

  it "infers type for generic class, with assign (1)" do
    assert_type(%(
      class Foo
      end

      class Gen(T)
        def initialize
          @x = @y = T.new
        end

        def x
          @x
        end
      end

      Gen(Foo).new.x
      )) { types["Foo"] }
  end

  it "infers type for generic class, with assign (2)" do
    assert_type(%(
      class Foo
      end

      class Gen(T)
        def initialize
          @x = @y = T.new
        end

        def y
          @y
        end
      end

      Gen(Foo).new.y
      )) { types["Foo"] }
  end

  it "infers type for non-generic class, with assign" do
    assert_type(%(
      class Foo
        @x : Int32
        @y : Int32

        def initialize
          @x = @y = 1
        end

        def y
          @y
        end
      end

      Foo.new.y
      )) { int32 }
  end

  it "infers type for generic module" do
    assert_type(%(
      class Foo
      end

      module Moo(T)
        def initialize
          @x = T.new
        end

        def x
          @x
        end
      end

      class Gen(T)
        include Moo(T)
      end

      Gen(Foo).new.x
      )) { types["Foo"] }
  end

  it "infers type to be nilable if not initialized" do
    assert_type(%(
      class Foo
        def x
          @x = 1
          @x
        end
      end

      Foo.new.x
      )) { nilable int32 }
  end

  it "infers type to be non-nilable if initialized in all initialize" do
    assert_type(%(
      class Foo
        def initialize
          @x = 1
        end

        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "errors if not initialized in all initialize" do
    assert_error %(
      class Foo
        def initialize
          @x = 1
        end

        def initialize(x)
        end

        def x
          @x
        end
      end

      Foo.new.x
      ),
      "this 'initialize' doesn't explicitly initialize instance variable '@x' of Foo, rendering it nilable"
  end

  it "doesn't error if not initializes in all initialize because declared as nilable" do
    assert_type(%(
      class Foo
        @x : Int32?

        def initialize
          @x = 1
        end

        def initialize(x)
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { nilable int32 }
  end

  it "infers type from argument with restriction, in generic" do
    assert_type(%(
      class Foo(T)
        def initialize(@x : T)
        end

        def x
          @x
        end
      end

      Foo.new(1).x
      )) { int32 }
  end

  it "says undefined instance variable on read" do
    assert_error %(
      class Foo
        def x
          @x
        end
      end

      Foo.new.x
      ),
      "Can't infer the type of instance variable '@x' of Foo"
  end

  it "says undefined instance variable on assign" do
    assert_error %(
      class Foo
        def x
          a = 1
          @x = a
        end
      end

      Foo.new.x
      ),
      "Can't infer the type of instance variable '@x' of Foo"
  end

  it "errors if declaring instance var and turns out to be nilable" do
    assert_error %(
      class Foo
        @x : Int32
      end
      ),
      "instance variable '@x' of Foo was not initialized in all of the 'initialize' methods, rendering it nilable"
  end

  it "doesn't if declaring nilable instance var and turns out to be nilable" do
    assert_type(%(
      class Foo
        @x : Int32?

        def x
          @x
        end
      end

      Foo.new.x
      )) { nilable int32 }
  end

  it "errors if declaring instance var and turns out to be nilable, in generic type" do
    assert_error %(
      class Foo(T)
        @x : T
      end
      ),
      "instance variable '@x' of Foo(T) was not initialized in all of the 'initialize' methods, rendering it nilable"
  end

  it "errors if declaring instance var and turns out to be nilable, in generic module type" do
    assert_error %(
      module Moo(T)
        @x : T
      end

      class Foo
        include Moo(Int32)
      end
      ),
      "instance variable '@x' of Foo was not initialized in all of the 'initialize' methods, rendering it nilable"
  end

  it "doesn't error if declaring instance var and doesn't out to be nilable, in generic module type" do
    assert_type(%(
      module Moo(T)
        @x : T

        def x
          @x
        end
      end

      class Foo
        include Moo(Int32)

        def initialize(@x)
        end
      end

      foo = Foo.new(1)
      foo.x
      )) { int32 }
  end

  it "errors if declaring instance var and turns out to be nilable, in generic module type in generic type" do
    assert_error %(
      module Moo(T)
        @x : T
      end

      class Foo(T)
        include Moo(T)
      end
      ),
      "instance variable '@x' of Foo(T) was not initialized in all of the 'initialize' methods, rendering it nilable"
  end

  it "doesn't error if not initializing variables but calling super" do
    assert_type(%(
      class Foo
        @x : Int32

        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      class Bar < Foo
        def initialize(x)
          super()
        end
      end

      Bar.new(10).x
      )) { int32 }
  end

  it "errors if not initializing super variables" do
    assert_error %(
      class Foo
        @x : Int32

        def initialize
          @x = 1
        end
      end

      class Bar < Foo
        def initialize
        end
      end
      ),
      "this 'initialize' doesn't initialize instance variable '@x' of Foo, with Bar < Foo, rendering it nilable"
  end

  it "errors if not initializing super variables (2)" do
    assert_error %(
      class Foo
        @x : Int32

        def initialize
          @x = 1
        end
      end

      class Bar < Foo
        def initialize
          @y = 2
        end
      end
      ),
      "this 'initialize' doesn't initialize instance variable '@x' of Foo, with Bar < Foo, rendering it nilable"
  end

  it "errors if not initializing super variables (3)" do
    assert_error %(
      class Foo
        def initialize
          @x = 1
        end
      end

      class Bar < Foo
        def initialize
          @y = 2
        end
      end
      ),
      "this 'initialize' doesn't initialize instance variable '@x' of Foo, with Bar < Foo, rendering it nilable"
  end

  it "errors if not initializing super variable in generic" do
    assert_error %(
      class Foo(T)
        def initialize
          @x = 1
        end
      end

      class Bar(T) < Foo(T)
        def initialize
          @y = 2
        end
      end
      ),
      "this 'initialize' doesn't initialize instance variable '@x', rendering it nilable"
  end

  it "doesn't error if not calling super but initializing all variables" do
    assert_type(%(
      class Foo
        @x : Int32

        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      class Bar < Foo
        def initialize(x)
          @x = 2
        end
      end

      Bar.new(10).x
      )) { int32 }
  end

  it "doesn't error if not initializing variables but calling super in parent parent" do
    assert_type(%(
      class Foo
        @x : Int32

        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      class Bar < Foo
      end

      class Baz < Bar
        def initialize(x)
          super()
        end
      end

      Baz.new(10).x
      )) { int32 }
  end

  it "doesn't error if not initializing variables but calling super for module" do
    assert_type(%(
      module Moo
        @x : Int32

        def initialize
          @x = 1
        end

        def x
          @x
        end
      end

      class Foo
        include Moo

        def initialize(x)
          super()
        end
      end

      Foo.new(10).x
      )) { int32 }
  end

  it "doesn't error if not initializing variables but calling super for generic module" do
    assert_type(%(
      module Moo(T)
        @x : T

        def initialize(@x)
        end

        def x
          @x
        end
      end

      class Foo
        include Moo(Int32)

        def initialize(x)
          super(x)
        end
      end

      Foo.new(10).x
      )) { int32 }
  end

  it "ignores redefined initialize (#456)" do
    assert_type(%(
      class A
        def initialize
          @a = 1
        end

        def initialize
          @a = 1
          @b = 2
        end

        def a
          @a
        end

        def b
          @b
        end
      end

      a = A.new
      a.a + a.b
      )) { int32 }
  end

  it "ignores super module initialize (#456)" do
    assert_type(%(
      module B
        def initialize
          @a = 1
        end
      end

      class A
        include B

        def initialize
          @a = 1
          @b = 2
        end

        def a
          @a
        end

        def b
          @b
        end
      end

      a = A.new
      a.a + a.b
      )) { int32 }
  end

  it "obeys super module initialize (#456)" do
    assert_type(%(
      module A
        def initialize
          @a = 1
        end

        def a
          @a
        end
      end

      class B
        include A

        def initialize
          @b = 2
          super
        end

        def b
          @b
        end
      end

      b = B.new
      b.a + b.b
      )) { int32 }
  end

  it "doesn't error if initializing var in superclass, and then empty initialize" do
    assert_type(%(
      class Foo
        @x : Int32
        @x = 1

        def x
          @x
        end
      end

      class Bar < Foo
        def initialize
        end
      end

      Bar.new.x
      )) { int32 }
  end

  it "doesn't error if calling initialize from another initialize (1)" do
    assert_type(%(
      class Foo
        def initialize(@x : Int32)
        end

        def initialize
          initialize(1)
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "doesn't error if calling initialize from another initialize (2)" do
    assert_type(%(
      class Foo
        def initialize(@x : Int32)
          @y = nil
        end

        def initialize
          initialize(1)
          @y = 2
        end

        def y
          @y
        end
      end

      Foo.new.y
      )) { nilable int32 }
  end

  it "infers nilable instance var of generic type" do
    assert_type(%(
      class Foo(T)
        def set
          @coco = 2
        end

        def coco
          @coco
        end
      end

      f = Foo(Int32).new
      f.coco
      )) { nilable int32 }
  end

  it "infers nilable instance var of generic module" do
    assert_type(%(
      module Moo(T)
        def set
          @coco = 2
        end

        def coco
          @coco
        end
      end

      class Foo(T)
        include Moo(T)
      end

      f = Foo(Int32).new
      f.coco
      )) { nilable int32 }
  end

  it "infers type to be nilable if self is used before assigning to a variable" do
    assert_type(%(
      class Foo
        def initialize
          self
          @x = 1
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { nilable int32 }
  end

  it "infers type to be nilable if self is used in same assign" do
    assert_type(%(
      def foo(x)
      end

      class Foo
        def initialize
          @x = 1 || foo(self)
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { nilable int32 }
  end

  it "doesn't infer type to be nilable if using self.class" do
    assert_type(%(
      class Foo
        def initialize
          self.class
          @x = 1
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  pending "doesn't infer type to be nilable if using self.class in call in assign" do
    assert_type(%(
      def foo(x)
      end

      class Foo
        def initialize
          @x = 1 || foo(self.class)
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "doesn't error if not initializing nilable var in subclass" do
    assert_type(%(
      class Foo
        @x : Int32?

        def initialize(@x)
        end

        def x
          @x
        end
      end

      class Bar < Foo
        def initialize
        end
      end

      Bar.new.x
      )) { nilable int32 }
  end

  it "considers var as assigned in multi-assign" do
    assert_type(%(
      def some
        {1, 2}
      end

      class Foo
        @x : Int32
        @y : Int32

        def initialize
          @x, @y = some
        end

        def x
          @x
        end

        def y
          @y
        end
      end

      foo = Foo.new
      foo.x + foo.y
      )) { int32 }
  end

  it "infers from another instance var" do
    assert_type(%(
      class Foo
        def initialize
          @x = 1
          @y = @x
        end

        def y
          @y
        end
      end

      Foo.new.y
      )) { int32 }
  end

  it "infers from another instance var with type declaration" do
    assert_type(%(
      class Foo
        @x : Int32

        def initialize(@x)
          @y = @x
        end

        def y
          @y
        end
      end

      Foo.new(1).y
      )) { int32 }
  end

  it "infers from another instance var in generic type" do
    assert_type(%(
      class Bar
      end

      class Foo(T)
        def initialize
          @x = T.new
          @y = @x
        end

        def y
          @y
        end
      end

      Foo(Bar).new.y
      )) { types["Bar"] }
  end

  it "infers from another instance var in generic type with type declaration" do
    assert_type(%(
      class Bar
      end

      class Foo(T)
        @x : T

        def initialize(@x)
          @y = @x
        end

        def y
          @y
        end
      end

      Foo(Bar).new(Bar.new).y
      )) { types["Bar"] }
  end

  it "errors on udefined instance var and subclass calling super" do
    assert_error %(
      class Foo
        def initialize(@x)
        end

        def x
          @x
        end
      end

      class Bar < Foo
        def initialize(x)
          super
          @x = x
        end
      end

      point = Bar.new(1)
      Foo.new(1).x
      ),
      "Can't infer the type of instance variable '@x' of Bar"
  end

  it "infers type from array literal in generic type" do
    assert_type(%(
      class Foo(T)
        def initialize
          @array = [] of T
        end

        def array
          @array
        end
      end

      Foo(Int32).new.array
      )) { array_of(int32) }
  end

  it "infers type from hash literal in generic type" do
    assert_type(%(
      class Foo(T)
        def initialize
          @array = {} of T => Float64
        end

        def array
          @array
        end
      end

      Foo(Int32).new.array
      )) { hash_of(int32, float64) }
  end

  it "infers type from array literal with literals in generic type" do
    assert_type(%(
      require "prelude"

      class Foo(T)
        def initialize
          @array = [0]
        end

        def array
          @array
        end
      end

      Foo(Float64).new.array
      )) { array_of(int32) }
  end

  it "infers type from hash literal with literals in generic type" do
    assert_type(%(
      require "prelude"

      class Foo(T)
        def initialize
          @hash = {0 => :foo}
        end

        def hash
          @hash
        end
      end

      Foo(Float64).new.hash
      )) { hash_of(int32, symbol) }
  end

  it "infers from restriction using virtual type" do
    assert_type(%(
      class Foo; end
      class Bar < Foo; end

      class Baz
        def initialize(@x : Foo)
        end

        def x
          @x
        end
      end

      Baz.new(Foo.new).x
      )) { types["Foo"].virtual_type! }
  end

  it "doesn't duplicate instance var in subclass" do
    result = infer_type(%(
      class Foo
        def initialize(@x : Int32)
        end

        def x
          @x
        end
      end

      class Bar < Foo
        @x : Int32
      end
      ))

    foo = result.program.types["Foo"].as(NonGenericClassType)
    foo.instance_vars["@x"].type.should eq(result.program.int32)

    bar = result.program.types["Bar"].as(NonGenericClassType)
    bar.instance_vars.empty?.should be_true
  end

  it "infers type from custom array literal" do
    assert_type(%(
      class Foo
        def initialize
        end

        def <<(v)
        end
      end

      class Bar
        def initialize
          @x = Foo{1, 2, 3}
        end

        def x
          @x
        end
      end

      Bar.new.x
      )) { types["Foo"] }
  end

  it "infers type from custom generic array literal" do
    assert_type(%(
      class Foo(T)
        def initialize
        end

        def <<(v)
        end
      end

      class Bar
        def initialize
          @x = Foo{1, 2, 3}
        end

        def x
          @x
        end
      end

      Bar.new.x
      )) { generic_class "Foo", int32 }
  end

  it "infers type from custom hash literal" do
    assert_type(%(
      class Foo
        def initialize
        end

        def []=(k, v)
        end
      end

      class Bar
        def initialize
          @x = Foo{1 => 2}
        end

        def x
          @x
        end
      end

      Bar.new.x
      )) { types["Foo"] }
  end

  it "infers type from custom generic hash literal" do
    assert_type(%(
      class Foo(K, V)
        def initialize
        end

        def []=(k, v)
        end
      end

      class Bar
        def initialize
          @x = Foo{1 => "foo"}
        end

        def x
          @x
        end
      end

      Bar.new.x
      )) { generic_class "Foo", int32, string }
  end

  it "infers type from custom array literal in generic" do
    assert_type(%(
      class Foo
        def initialize
        end

        def <<(v)
        end
      end

      class Bar(T)
        def initialize
          @x = Foo{1, 2, 3}
        end

        def x
          @x
        end
      end

      Bar(Int32).new.x
      )) { types["Foo"] }
  end

  it "infers type from custom hash literal in generic" do
    assert_type(%(
      class Foo
        def initialize
        end

        def []=(k, v)
        end
      end

      class Bar(T)
        def initialize
          @x = Foo{1 => 2}
        end

        def x
          @x
        end
      end

      Bar(Int32).new.x
      )) { types["Foo"] }
  end

  it "says can't infer type if only nil was assigned" do
    assert_error %(
      class Foo
        def initialize
          @x = nil
        end

        def x
          @x
        end
      end

      Foo.new.x
      ),
      "Can't infer the type of instance variable '@x' of Foo"
  end

  it "says can't infer type if only nil was assigned, in generic type" do
    assert_error %(
      class Foo(T)
        def initialize
          @x = nil
        end

        def x
          @x
        end
      end

      Foo(Int32).new.x
      ),
      "Can't infer the type of instance variable '@x' of Foo"
  end

  it "allows nil instance var because it's a generic type" do
    assert_type(%(
      class Foo(T)
        def initialize(@x : T)
        end

        def x
          @x
        end
      end

      Foo.new(nil).x
      )) { |mod| mod.nil }
  end

  it "uses virtual types in fun" do
    assert_type(%(
      class Node; end
      class SubNode < Node; end

      class Foo
        def initialize(@x : Node -> Node)
        end

        def x
          @x
        end
      end

      Foo.new(->(x : Node) { x }).x
      )) { fun_of(types["Node"].virtual_type, types["Node"].virtual_type) }
  end

  it "uses virtual types in union" do
    assert_type(%(
      class Node; end
      class SubNode < Node; end

      class Foo
        def initialize(@x : Node | Int32)
        end

        def x
          @x
        end
      end

      Foo.new(1).x
      )) { union_of(types["Node"].virtual_type, int32) }
  end

  it "uses virtual types in self" do
    assert_type(%(
      class Node
        def initialize
          @x = nil
        end

        def initialize(@x : self)
        end

        def x
          @x
        end
      end

      class SubNode < Node; end

      Node.new.x
      )) { nilable types["Node"].virtual_type }
  end

  it "infers from Pointer.malloc" do
    assert_type(%(
      class Foo
        def initialize
          @x = Pointer(Int32).malloc(1_u64)
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { pointer_of(int32) }
  end

  it "infers from Pointer.malloc with two arguments" do
    assert_type(%(
      require "prelude"

      class Foo
        def initialize
          @x = Pointer.malloc(10, 1_u8)
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { pointer_of(uint8) }
  end

  it "infers from Pointer.null" do
    assert_type(%(
      require "prelude"

      class Foo
        def initialize
          @x = Pointer(Int32).null
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { pointer_of(int32) }
  end

  it "infers from Pointer.malloc in generic type" do
    assert_type(%(
      class Foo(T)
        def initialize
          @x = Pointer(T).malloc(1_u64)
        end

        def x
          @x
        end
      end

      Foo(Int32).new.x
      )) { pointer_of(int32) }
  end

  it "infers from Pointer.null in generic type" do
    assert_type(%(
      require "prelude"

      class Foo(T)
        def initialize
          @x = Pointer(T).null
        end

        def x
          @x
        end
      end

      Foo(Int32).new.x
      )) { pointer_of(int32) }
  end

  it "infers from Pointer.malloc with two arguments in generic type" do
    assert_type(%(
      require "prelude"

      class Foo(T)
        def initialize
          @x = Pointer.malloc(10, 1_u8)
        end

        def x
          @x
        end
      end

      Foo(Int32).new.x
      )) { pointer_of(uint8) }
  end

  it "doesn't infer generic type without type argument inside generic" do
    assert_error %(
      class Bar(T)
        def self.new
          1
        end
      end

      class Foo(T)
        def initialize
          @bar = Bar.new
        end

        def bar
          @bar
        end
      end

      Foo(Int32).new.bar
      ),
      "Can't infer the type of instance variable '@bar' of Foo"
  end

  it "doesn't crash on missing var on subclass, with superclass not specifying a type" do
    assert_error %(
      class Foo
        def initialize(@x)
        end
      end

      class Bar < Foo
        def initialize
        end
      end

      Bar.new
      ),
      "this 'initialize' doesn't initialize instance variable '@x', rendering it nilable"
  end

  it "doesn't complain if not initliazed in one initialize, but has initializer (#2465)" do
    assert_type(%(
      class Foo
        @x = 1

        def initialize(@x)
        end

        def initialize
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "can declare type even if included module has a guessed var" do
    assert_type(%(
      module Moo
        def foo
          @x = 1
        end
      end

      class Foo
        include Moo

        @x : Int32 | Float64

        def initialize
          @x = 1.5
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { union_of int32, float64 }
  end

  it "doesn't complain if declared type is recursive alias that's nilable" do
    assert_type(%(
      class Bar(T)
      end

      alias Rec = Int32 | Nil | Bar(Rec)

      class Foo
        @x : Rec

        def x
          @x
        end
      end

      Foo.new.x
      )) { types["Rec"] }
  end

  it "infers from assign to local var (#2467)" do
    assert_type(%(
      class Foo
        def initialize
          @x = x = 1
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "infers from assign to local var in generic type (#2467)" do
    assert_type(%(
      class Foo(T)
        def initialize
          @x = x = 1
        end

        def x
          @x
        end
      end

      Foo(Float64).new.x
      )) { int32 }
  end

  it "infers from class method that has type annotation" do
    assert_type(%(
      class Bar
        def self.bar : Bar
          Bar.new
        end
      end

      class Foo
        def initialize
          @bar = Bar.bar
        end

        def bar
          @bar
        end
      end

      Foo.new.bar
      )) { types["Bar"] }
  end

  it "infers from class method that has type annotation, in generic class" do
    assert_type(%(
      class Bar
        def self.bar : Bar
          Bar.new
        end
      end

      class Foo(T)
        def initialize
          @bar = Bar.bar
        end

        def bar
          @bar
        end
      end

      Foo(Int32).new.bar
      )) { types["Bar"] }
  end

  it "infers from generic class method that has type annotation" do
    assert_type(%(
      class Bar(T)
        def self.bar : self
          Bar(T).new
        end
      end

      class Foo
        def initialize
          @bar = Bar(Int32).bar
        end

        def bar
          @bar
        end
      end

      Foo.new.bar
      )) { generic_class "Bar", int32 }
  end

  it "infers from generic class method that has type annotation, without instantiating" do
    assert_type(%(
      class Bar(T)
        def self.bar : Int32
          1
        end
      end

      class Foo
        def initialize
          @bar = Bar.bar
        end

        def bar
          @bar
        end
      end

      Foo.new.bar
      )) { int32 }
  end

  it "infers from class method that has type annotation, with overload" do
    assert_type(%(
      class Baz
      end

      class Bar
        def self.bar : Baz
          Baz.new
        end

        def self.bar(x) : Bar
          Bar.new
        end

        def self.bar(x) : Baz
          yield
          Bar.new
        end
      end

      class Foo
        def initialize
          @bar = Bar.bar(1)
        end

        def bar
          @bar
        end
      end

      Foo.new.bar
      )) { types["Bar"] }
  end

  it "infers from class method that has type annotation, with multiple overloads matching, all with the same type" do
    assert_type(%(
      class Bar
        def self.bar(x : Int32) : Bar
          Bar.new
        end

        def self.bar(x : String) : Bar
          Bar.new
        end
      end

      class Foo
        def initialize(x)
          @bar = Bar.bar(x)
        end

        def bar
          @bar
        end
      end

      Foo.new(1).bar
      )) { types["Bar"] }
  end

  it "infers from new with return type" do
    assert_type(%(
      class Foo
        def self.new : Int32
          1
        end
      end

      class Bar
        def initialize
          @x = Foo.new
        end

        def x
          @x
        end
      end

      Bar.new.x
      )) { int32 }
  end

  it "infers from new with return type in generic type" do
    assert_type(%(
      class Foo
        def self.new : Int32
          1
        end
      end

      class Bar(T)
        def initialize
          @x = Foo.new
        end

        def x
          @x
        end
      end

      Bar(Float64).new.x
      )) { int32 }
  end

  it "infers from new with return type returning generic" do
    assert_type(%(
      class Foo(T)
        def self.new : Bar(T)
          Bar(T).new
        end
      end

      class Bar(T)
      end

      class Baz
        def initialize
          @x = Foo(Int32).new
        end

        def x
          @x
        end
      end

      Baz.new.x
      )) { generic_class "Bar", int32 }
  end

  it "guesses from new on abstract class" do
    assert_type(%(
      abstract class Foo
        def self.new : Bar
          Bar.new(1)
        end
      end

      class Bar < Foo
        def initialize(x)
        end
      end

      class Baz
        def initialize
          @foo = Foo.new
        end

        def foo
          @foo
        end
      end

      Baz.new.foo
      )) { types["Bar"] }
  end

  it "errors on undefined constant" do
    assert_error %(
      class Foo
        def initialize
          @x = Bar.new
        end
      end

      Foo.new
      ),
      "undefined constant Bar"
  end

  it "infers from class method that invokes new" do
    assert_type(%(
      class Foo
        def initialize
          @x = Bar.create
        end

        def x
          @x
        end
      end

      class Bar
        def self.create
          new
        end
      end

      Foo.new.x
      )) { types["Bar"] }
  end

  it "infers from class method that has number literal" do
    assert_type(%(
      class Foo
        def initialize
          @x = Bar.default_num
        end

        def x
          @x
        end
      end

      class Bar
        def self.default_num
          1
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "infers from class method that refers to constant" do
    assert_type(%(
      class Foo
        def initialize
          @x = Bar.default_instance
        end

        def x
          @x
        end
      end

      class Bar
        DEFAULT = new

        def self.default_instance
          DEFAULT
        end
      end

      Foo.new.x
      )) { types["Bar"] }
  end

  it "infer from class method with multiple statements and return" do
    assert_type(%(
      class Foo
        def initialize
          @x = Bar.default
        end

        def x
          @x
        end
      end

      class Bar
        def self.default
          if 1 == 2
            return nil
          end
          1
        end
      end

      Foo.new.x
      )) { nilable int32 }
  end

  it "doesn't infer from class method with multiple statements and return, on non-easy return" do
    assert_error %(
      class Foo
        def initialize
          @x = Bar.default
        end

        def x
          @x
        end
      end

      class Bar
        def self.default
          if 1 == 2
            a = 1
            return a
          end
          1
        end
      end

      Foo.new.x
      ),
      "Can't infer the type of instance variable '@x' of Foo"
  end

  it "doesn't infer from class method with multiple statements and return, on non-easy return (2)" do
    assert_error %(
      class Foo
        def initialize
          @x = Bar.default
        end

        def x
          @x
        end
      end

      class Bar
        def self.default
          if 1 == 2
            a = 1
            return a
          else
            1
          end
        end
      end

      Foo.new.x
      ),
      "Can't infer the type of instance variable '@x' of Foo"
  end

  it "infer from class method where new is redefined" do
    assert_type(%(
      class Foo
        def initialize
          @x = Bar.default
        end

        def x
          @x
        end
      end

      class Bar
        def self.default
          new
        end

        def self.new
          1
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "doesn't crash on recursive method call" do
    assert_error %(
      class Foo
        def initialize
          @x = Bar.default
        end

        def x
          @x
        end
      end

      class Bar
        def self.default
          Bar.default2
        end

        def self.default2
          Bar.default
        end
      end

      Foo.new.x
      ),
      "Can't infer the type of instance variable '@x' of Foo"
  end

  it "infers in multiple assign for tuple type (1)" do
    assert_type(%(
      class Foo
        def initialize
          @x, @y = Bar.method
        end

        def x
          @x
        end
      end

      class Bar
        def self.method : {Int32, Bool}
          {1, true}
        end
      end

      Foo.new.x
      )) { int32 }
  end

  it "says can't infer (#2536)" do
    assert_error %(
      require "prelude"

      class A(T)
        def initialize(@arg : T)
          @foo = [bar]
        end

        def initialize(@arg : T)
          yield 3
        end

        def bar
          3
        end
      end

      A.new(3).foo
      ),
      "Can't infer the type of instance variable '@foo' of A(Int32)"
  end

  it "doesn't crash when inferring from new without matches (#2538)" do
    assert_error %(
      class Foo
        @@default = Foo.new

        def initialize(@attr)
        end
      end

      Foo.new("aaaa")
      ),
      "wrong number of arguments for 'Foo.new'"
  end

  it "guesses inside macro if" do
    assert_type(%(
      {% if true %}
        class Foo
          def initialize
            @x = 1
          end

          def x
            @x
          end
        end
      {% end %}

      Foo.new.x
      )) { int32 }
  end

  it "guesses inside macro expression" do
    assert_type(%(
      {{ "class Foo; def initialize; @x = 1; end; def x; @x; end; end".id }}

      Foo.new.x
      )) { int32 }
  end

  it "guesses inside macro for" do
    assert_type(%(
      {% for name in %w(Foo) %}
        class {{name.id}}
          def initialize
            @x = 1
          end

          def x
            @x
          end
        end
      {% end %}

      Foo.new.x
      )) { int32 }
  end

  it "can't infer type from initializer" do
    assert_error %(
      class Foo
        @x = 1 + 2

        def x
          @x
        end
      end

      Foo.new.x
      ),
      "Can't infer the type of instance variable '@x' of Foo"
  end

  it "can't infer type from initializer in non-generic module" do
    assert_error %(
      module Moo
        @x = 1 + 2

        def x
          @x
        end
      end

      class Foo
        include Moo
      end

      Foo.new.x
      ),
      "Can't infer the type of instance variable '@x' of Moo"
  end

  it "can't infer type from initializer in generic module type" do
    assert_error %(
      module Moo(T)
        @x = 1 + 2

        def x
          @x
        end
      end

      class Foo
        include Moo(Int32)
      end

      Foo.new.x
      ),
      "Can't infer the type of instance variable '@x' of Moo(T)"
  end

  it "can't infer type from initializer in generic class type" do
    assert_error %(
      class Foo(T)
        @x = 1 + 2

        def x
          @x
        end
      end

      Foo(Int32).new.x
      ),
      "Can't infer the type of instance variable '@x' of Foo(T)"
  end

  it "infers type from self (#2575)" do
    assert_type(%(
      class Foo
        def initialize
          @x = self
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { types["Foo"] }
  end

  it "infers type from self as virtual type (#2575)" do
    assert_type(%(
      class Foo
        def initialize
          @x = self
        end

        def x
          @x
        end
      end

      class Bar < Foo
      end

      Foo.new.x
      )) { types["Foo"].virtual_type! }
  end

  it "declares as named tuple" do
    assert_type(%(
      class Foo
        @x : NamedTuple(x: Int32, y: Char)

        def initialize
          a = {x: 1, y: 'a'}
          @x = a
        end

        def x
          @x
        end
      end

      Foo.new.x
      )) { named_tuple_of({"x": int32, "y": char}) }
  end

  it "doesn't complain in second part of #2575" do
    assert_type(%(
      class Foo
        @a : Int32

        def initialize
          @a = 5
        end

        def initialize(b)
          initialize
        end

        def a
          @a
        end
      end

      class Bar < Foo
      end

      Bar.new.a
      )) { int32 }
  end

  # -----------------
  # ||| OLD SPECS |||
  # vvv           vvv

  it "declares instance var which appears in initialize" do
    result = assert_type("
      class Foo
        @x : Int32

        def initialize
          @x = 1
        end
      end

      Foo.new
      ") { types["Foo"] }

    mod = result.program

    foo = mod.types["Foo"].as(NonGenericClassType)
    foo.instance_vars["@x"].type.should eq(mod.int32)
  end

  it "declares instance var of generic class" do
    result = assert_type("
      class Foo(T)
        @x : T

        def initialize(@x)
        end
      end

      Foo(Int32).new(1)
      ") do
      foo = types["Foo"].as(GenericClassType)
      foo_i32 = foo.instantiate([int32] of TypeVar)
      foo_i32.lookup_instance_var("@x").type.should eq(int32)
      foo_i32
    end
  end

  it "declares instance var of generic class after reopen" do
    result = assert_type("
      class Foo(T)
      end

      f = Foo(Int32).new(1)

      class Foo(T)
        @x : T

        def initialize(@x : T)
        end
      end

      f") do
      foo = types["Foo"].as(GenericClassType)
      foo_i32 = foo.instantiate([int32] of TypeVar)
      foo_i32.lookup_instance_var("@x").type.should eq(int32)
      foo_i32
    end
  end

  it "declares instance var with initial value" do
    assert_type("
      class Foo
        @x = 0

        def x
          @x
        end
      end

      Foo.new.x
      ") { int32 }
  end

  it "declares instance var with initial value, with subclass" do
    assert_type("
      class Foo
        @x = 0

        def x
          @x
        end
      end

      class Bar < Foo
        def initialize
          @x = 1
          @z = 1
        end
      end

      Bar.new.x
      ") { int32 }
  end

  it "errors if declaring generic type without type vars" do
    assert_error %(
      class Foo(T)
      end

      class Baz
        @x : Foo
      end
      ),
      "can't declare variable of generic non-instantiated type Foo"
  end

  it "errors (for now) when typing a local variable" do
    assert_error %(
      x : Int32
      ),
      "declaring the type of a local variable is not yet supported"
  end

  it "errors when typing an instance variable inside a method" do
    assert_error %(
      def foo
        @x : Int32
      end

      foo
      ),
      "declaring the type of an instance variable must be done at the class level"
  end

  it "declares instance var with union type with a virtual member" do
    assert_type("
      class Parent; end
      class Child < Parent; end

      class Foo
        @x : Parent?

        def x
          @x
        end
      end

      Foo.new.x") { |mod| mod.union_of(mod.types["Parent"].virtual_type!, mod.nil) }
  end

  it "declares with `self`" do
    assert_type(%(
      class Foo
        @foo : self

        def initialize
          @foo = uninitialized self
        end

        def foo
          @foo
        end
      end

      Foo.new.foo
      )) { types["Foo"] }
  end
end
