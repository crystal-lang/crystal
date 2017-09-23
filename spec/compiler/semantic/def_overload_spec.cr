require "../../spec_helper"

describe "Semantic: def overload" do
  it "types a call with overload" do
    assert_type("def foo; 1; end; def foo(x); 2.5; end; foo") { int32 }
  end

  it "types a call with overload with yield" do
    assert_type("def foo; yield; 1; end; def foo; 2.5; end; foo") { float64 }
  end

  it "types a call with overload with yield after typing another call without yield" do
    assert_type("
      def foo; yield; 1; end
      def foo; 2.5; end
      foo
      foo {}
    ") { int32 }
  end

  it "types a call with overload with yield the other way" do
    assert_type("def foo; yield; 1; end; def foo; 2.5; end; foo { 1 }") { int32 }
  end

  it "types a call with overload type first overload" do
    assert_type("def foo(x : Int); 2.5; end; def foo(x : Float); 1; end; foo(1)") { float64 }
  end

  it "types a call with overload type second overload" do
    assert_type("def foo(x : Int); 2.5; end; def foo(x : Float); 1; end; foo(1.5)") { int32 }
  end

  it "types a call with overload Object type first overload" do
    assert_type("
      class Foo
      end

      class Bar
      end

      def foo(x : Foo)
        2.5
      end

      def foo(x : Bar)
        1
      end

      foo(Foo.new)
      ") { float64 }
  end

  it "types a call with overload selecting the most restrictive" do
    assert_type("def foo(x); 1; end; def foo(x : Float); 1.1; end; foo(1.5)") { float64 }
  end

  it "types a call with overload selecting the most restrictive 2" do
    assert_type("
      def foo(x, y : Int)
        1
      end

      def foo(x : Int, y)
        1.1
      end

      def foo(x : Int, y : Int)
        'a'
      end

      foo(1, 1)
    ") { char }
  end

  it "types a call with overload matches virtual" do
    assert_type("
      class Foo; end

      def foo(x : Object)
        1
      end

      foo(Foo.new)
    ") { int32 }
  end

  it "types a call with overload matches virtual 2" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      def foo(x : Foo)
        1
      end

      def foo(x : Bar)
        1.5
      end

      foo(Bar.new)
    ") { float64 }
  end

  it "types a call with overload matches virtual 3" do
    assert_type("
      class Foo
      end

      class Bar < Foo
      end

      def foo(x : Foo)
        1
      end

      def foo(x : Bar)
        1.5
      end

      foo(Foo.new)
    ") { int32 }
  end

  it "types a call with overload self" do
    assert_type("
      class Foo
        def foo(x : self)
          1
        end

        def foo(x)
          1.5
        end
      end

      a = Foo.new
      a.foo(a)
    ") { int32 }
  end

  it "types a call with overload self other match" do
    assert_type("
      class Foo
        def foo(x : self)
          1
        end

        def foo(x)
          1.5
        end
      end

      a = Foo.new
      a.foo(1)
    ") { float64 }
  end

  it "types a call with overload self in included module" do
    assert_type("
      module Foo
        def foo(x : self)
          1
        end
      end

      class Bar
        def foo(x)
          1.5
        end
      end

      class Baz < Bar
        include Foo
      end

      b = Baz.new
      b.foo(b)
    ") { int32 }
  end

  it "types a call with overload self in included module other type" do
    assert_type("
      module Foo
        def foo(x : self)
          1
        end
      end

      class Bar
        def foo(x)
          1.5
        end
      end

      class Baz < Bar
        include Foo
      end

      b = Baz.new
      b.foo(Bar.new)
    ") { float64 }
  end

  it "types a call with overload self with inherited type" do
    assert_type("
      class Foo
        def foo(x : self)
          1
        end
      end

      class Bar < Foo
      end

      a = Foo.new
      a.foo(Bar.new)
    ") { int32 }
  end

  it "matches types with free variables" do
    assert_type("
      require \"prelude\"
      def foo(x : Array(T), y : T) forall T
        1
      end

      def foo(x, y)
        1.5
      end

      foo([1], 1)
    ") { int32 }
  end

  it "prefers more specifc overload than one with free variables" do
    assert_type("
      require \"prelude\"
      def foo(x : Array(T), y : T)
        1
      end

      def foo(x : Array(Int), y : Int)
        1.5
      end

      foo([1], 1)
    ") { float64 }
  end

  it "accepts overload with nilable type restriction" do
    assert_type("
      def foo(x : Int?)
        1
      end

      foo(1)
    ") { int32 }
  end

  it "dispatch call to def with restrictions" do
    assert_type("
      def foo(x : Value)
        1.1
      end

      def foo(x : Int32)
        1
      end

      a = 1 || 1.1
      foo(a)
    ") { union_of(int32, float64) }
  end

  it "dispatch call to def with restrictions" do
    assert_type("
      class Foo(T)
      end

      def foo(x : T) forall T
        Foo(T).new
      end

      foo 1
    ") { generic_class "Foo", int32 }
  end

  it "can call overload with generic restriction" do
    assert_type("
      class Foo(T)
      end

      def foo(x : Foo)
        1
      end

      foo(Foo(Int32).new)
    ") { int32 }
  end

  it "can call overload with aliased generic restriction" do
    assert_type("
      class Foo(T)
      end

      alias FooAlias = Foo

      def foo(x : FooAlias(T)) forall T
        1
      end

      foo(Foo(Int32).new)
    ") { int32 }
  end

  it "restrict matches to minimum necessary 1" do
    assert_type("
      def coco(x : Int, y); 1; end
      def coco(x, y : Int); 1.5; end
      def coco(x, y); 'a'; end

      coco 1, 1
    ") { int32 }
  end

  it "single type restriction wins over union" do
    assert_type("
      class Foo; end
      class Bar < Foo ;end

      def foo(x : Foo | Bar)
        1.1
      end

      def foo(x : Foo)
        1
      end

      foo(Foo.new || Bar.new)
    ") { int32 }
  end

  it "compare self type with others" do
    assert_type("
      class Foo
        def foo(x : Int)
          1.1
        end

        def foo(x : self)
          1
        end
      end

      x = Foo.new.foo(Foo.new)
    ") { int32 }
  end

  it "uses method defined in base class if the restriction doesn't match" do
    assert_type("
      class Foo
        def foo(x)
          1
        end
      end

      class Bar < Foo
        def foo(x : Float64)
          1.1
        end
      end

      Bar.new.foo(1)
    ") { int32 }
  end

  it "lookup matches in virtual type inside union" do
    assert_type("
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
      end

      class Baz
        def foo
          'a'
        end
      end

      a = Foo.new || Bar.new || Baz.new
      a.foo
    ") { union_of(int32, char) }
  end

  it "filter union type with virtual" do
    assert_type("
      class Foo
      end

      class Bar < Foo
        def bar
          1
        end
      end

      def foo(x : Bar)
        x.bar
      end

      def foo(x)
        1.1
      end

      foo(nil || Foo.new || Bar.new)
    ") { union_of(int32, float64) }
  end

  it "restrict virtual type with virtual type" do
    assert_type("
      def foo(x : T, y : T) forall T
        1
      end

      class Foo
      end

      class Bar < Foo
      end

      x = Foo.new || Bar.new
      foo(x, x)
    ") { int32 }
  end

  it "restricts union to generic class" do
    assert_type("
      class Foo(T)
      end

      def foo(x : Foo(T)) forall T
        1
      end

      def foo(x : Int)
        'a'
      end

      x = 1 || Foo(Int32).new
      foo(x)
    ") { union_of(int32, char) }
  end

  it "matches on partial union" do
    assert_type("
      require \"prelude\"

      def foo(x : Int32 | Float64)
        x.abs
        1
      end

      def foo(x : Char)
        x.ord
        'a'
      end

      foo 1 || 1.5 || 'a'
    ") { union_of(int32, char) }
  end

  pending "restricts on generic type with free type arg" do
    assert_type("
      require \"reference\"

      class Object
        def equal(expectation)
          expectation == self
        end
      end

      class Foo(T)
        def ==(other : Foo(U))
          1
        end
      end

      a = Foo(Int).new
      a.equal(a)
      ") { union_of(bool, int32) }
  end

  pending "restricts on generic type without type arg" do
    assert_type("
      require \"reference\"

      class Object
        def equal(expectation)
          expectation == self
        end
      end

      class Foo(T)
        def ==(other : Foo)
          1
        end
      end

      a = Foo(Int).new
      a.equal(a)
    ") { union_of(bool, int32) }
  end

  it "matches generic class instance type with another one" do
    assert_type("
      require \"prelude\"
      class Foo
      end

      class Bar < Foo
      end

      a = [] of Array(Foo)
      a.push [Foo.new, Bar.new]
      1
      ") { int32 }
  end

  it "errors if generic type doesn't match" do
    assert_error "
      class Foo(T)
      end

      def foo(x : Foo(Int32))
      end

      foo Foo(Int32 | Float64).new
      ",
      "no overload matches"
  end

  it "gets free variable from union restriction" do
    assert_type("
      def foo(x : Nil | U) forall U
        U
      end

      foo(1 || nil)
      ") { int32.metaclass }
  end

  it "gets free variable from union restriction (2)" do
    assert_type("
      def foo(x : Nil | U) forall U
        U
      end

      foo(nil || 1)
      ") { int32.metaclass }
  end

  it "gets free variable from union restriction without a union" do
    assert_type("
      def foo(x : Nil | U) forall U
        U
      end

      foo(1)
      ") { int32.metaclass }
  end

  it "matches a generic module argument" do
    assert_type("
      module Bar(T)
      end

      class Foo
        include Bar(Int32)
      end

      def foo(x : Bar(Int32))
        1
      end

      foo(Foo.new)
      ") { int32 }
  end

  it "matches a generic module argument with free var" do
    assert_type("
      module Bar(T)
      end

      class Foo
        include Bar(Int32)
      end

      def foo(x : Bar(T)) forall T
        T
      end

      foo(Foo.new)
      ") { int32.metaclass }
  end

  it "matches a generic module argument with free var (2)" do
    assert_type("
      module Bar(T)
      end

      class Foo(T)
        include Bar(T)
      end

      def foo(x : Bar(T)) forall T
        T
      end

      foo(Foo(Int32).new)
      ") { int32.metaclass }
  end

  it "matches virtual type to union" do
    assert_type("
      abstract class Foo
      end

      class Bar < Foo
      end

      class Baz < Foo
      end

      def foo(x : Bar | Baz)
        1
      end

      node = Bar.new || Baz.new
      foo(node)
      ") { int32 }
  end

  it "doesn't match tuples of different sizes" do
    assert_error "
      def foo(x : {X, Y, Z})
        'a'
      end

      foo({1, 2})
      ",
      "no overload matches"
  end

  it "matches tuples of different sizes" do
    assert_type("
      def foo(x : {X, Y}) forall X, Y
        1
      end

      def foo(x : {X, Y, Z}) forall X, Y, Z
        'a'
      end

      x = {1, 2} || {1, 2, 3}
      foo x
      ") { union_of(int32, char) }
  end

  it "matches tuples and uses free var" do
    assert_type("
      def foo(x : {X, Y}) forall X, Y
        Y
      end

      foo({1, 2.5})
      ") { float64.metaclass }
  end

  it "matches tuple with underscore" do
    assert_type("
      def foo(x : {_, _})
        x
      end

      foo({1, 2.5})
      ") { tuple_of([int32, float64] of Type) }
  end

  it "gives correct error message, looking up parent defs, when no overload matches" do
    assert_error %(
      class Foo
        def foo(x : Int32)
        end
      end

      class Bar < Foo
        def foo
        end
      end

      Bar.new.foo(1.5)
      ),
      "no overload matches"
  end

  it "doesn't match with wrong number of type arguments (#313)" do
    assert_error %(
      class Foo(A, B)
      end

      def foo(x : Foo(Int32))
      end

      foo Foo(Int32, Int32).new
      ),
      "wrong number of type vars for Foo(A, B) (given 1, expected 2)"
  end

  it "includes splat symbol in error message" do
    assert_error %(
      def foo(x : Int32, *bar)
      end

      foo 'a'
      ),
      "foo(x : Int32, *bar)"
  end

  it "says `no overload matches` instead of `can't instantiate abstract class` on wrong argument in new method" do
    assert_error %(
      abstract class Foo
        def self.new(x : Int)
        end
      end

      Foo.new('a')
      ),
      "no overload matches"
  end

  it "finds method after including module in generic module (#1201)" do
    assert_type(%(
      module Bar
        def foo
          'a'
        end
      end

      module Moo(T)
      end

      class Foo
        include Moo(Int32)

        def foo(x)
          1
        end
      end

      module Moo(T)
        include Bar
      end

      Foo.new.foo
      )) { char }
  end

  it "reports no overload matches with correct method owner (#2083)" do
    assert_error %(
      class Foo
        def foo(x : Int32)
          x + 1
        end
      end

      class Bar < Foo
        def foo(x : Int32)
          x + 2
        end
      end

      Bar.new.foo("hello")
      ),
      <<-MSG
       - Bar#foo(x : Int32)
       - Foo#foo(x : Int32)
      MSG
  end

  it "gives better error message with consecutive arguments sizes" do
    assert_error %(
      def foo
      end

      def foo(x)
      end

      def foo(x, y)
      end

      foo 1, 2, 3
      ),
      "wrong number of arguments for 'foo' (given 3, expected 0..2)"
  end

  it "errors if no overload matches on union against named arg (#2640)" do
    assert_error %(
      def f(a : Int32)
      end

      a = 1 || nil
      f(a: a)
      ),
      "no overload matches"
  end

  it "dispatches with named arg" do
    assert_type(%(
      def f(a : Int32, b : Int32)
        true
      end

      def f(b : Int32, a : Nil)
        'x'
      end

      a = 1 || nil
      f(a: a, b: 2)
      )) { union_of bool, char }
  end

  it "uses long name when no overload matches and name is the same (#1030)" do
    assert_error %(
      module Moo::String
        def self.foo(a : String, b : Bool)
          puts a if b
        end
      end

      Moo::String.foo("Hello, World!", true)
      ),
      " - Moo::String.foo(a : Moo::String, b : Bool)"
  end

  it "overloads on metaclass (#2916)" do
    assert_type(%(
      def foo(x : String.class)
        1
      end

      def foo(x : String?.class)
        'a'
      end

      {foo(String), foo(typeof("" || nil))}
      )) { tuple_of([int32, char]) }
  end

  it "overloads on metaclass (2) (#2916)" do
    assert_type(%(
      def foo(x : String.class)
        1
      end

      def foo(x : ::String.class)
        'a'
      end

      foo(String)
      )) { char }
  end

  it "overloads on metaclass (3) (#2916)" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      def foo(x : Foo.class)
        1
      end

      def foo(x : Bar.class)
        'a'
      end

      {foo(Bar), foo(Foo)}
      )) { tuple_of([char, int32]) }
  end

  it "doesn't crash on unknown metaclass" do
    assert_type(%(
      def foo(x : Foo.class)
      end

      def foo(x : Bar.class)
      end

      1
      )) { int32 }
  end

  it "overloads union against non-union (#2904)" do
    assert_type(%(
      def foo(x : Int32?)
        true
      end

      def foo(x : Int32)
        'a'
      end

      {foo(1), foo(nil)}
      )) { tuple_of([char, bool]) }
  end

  it "errors when binding free variable to different types" do
    assert_error %(
      def foo(x : T, y : T) forall T
      end

      foo(1, 'a')
      ),
      "no overload matches"
  end

  it "errors when binding free variable to different types (2)" do
    assert_error %(
      class Gen(T)
      end

      def foo(x : T, y : Gen(T)) forall T
      end

      foo(1, Gen(Char).new)
      ),
      "no overload matches"
  end

  it "overloads with named argument (#4465)" do
    assert_type(%(
			def do_something(value : Int32)
			  value + 1
			  1.5
			end

			def do_something(value : Char)
			  value.ord
			  false
			end

			do_something value: 7.as(Int32 | Char)
			)) { union_of float64, bool }
  end
end
