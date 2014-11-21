require "../../spec_helper"

describe "Type inference: def overload" do
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
    assert_type("def foo(x : Int); 2.5; end; def foo(x : Double); 1; end; foo(1.5)") { int32 }
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
    assert_type("def foo(x); 1; end; def foo(x : Double); 1.1; end; foo(1.5)") { float64 }
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
      class A; end

      def foo(x : Object)
        1
      end

      foo(A.new)
    ") { int32 }
  end

  it "types a call with overload matches virtual 2" do
    assert_type("
      class A
      end

      class B < A
      end

      def foo(x : A)
        1
      end

      def foo(x : B)
        1.5
      end

      foo(B.new)
    ") { float64 }
  end

  it "types a call with overload matches virtual 3" do
    assert_type("
      class A
      end

      class B < A
      end

      def foo(x : A)
        1
      end

      def foo(x : B)
        1.5
      end

      foo(A.new)
    ") { int32 }
  end

  it "types a call with overload self" do
    assert_type("
      class A
        def foo(x : self)
          1
        end

        def foo(x)
          1.5
        end
      end

      a = A.new
      a.foo(a)
    ") { int32 }
  end

  it "types a call with overload self other match" do
    assert_type("
      class A
        def foo(x : self)
          1
        end

        def foo(x)
          1.5
        end
      end

      a = A.new
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

      class A
        def foo(x)
          1.5
        end
      end

      class B < A
        include Foo
      end

      b = B.new
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

      class A
        def foo(x)
          1.5
        end
      end

      class B < A
        include Foo
      end

      b = B.new
      b.foo(A.new)
    ") { float64 }
  end

  it "types a call with overload self with inherited type" do
    assert_type("
      class A
        def foo(x : self)
          1
        end
      end

      class B < A
      end

      a = A.new
      a.foo(B.new)
    ") { int32 }
  end

  it "matches types with free variables" do
    assert_type("
      require \"prelude\"
      def foo(x : Array(T), y : T)
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

      def foo(x : T)
        Foo(T).new
      end

      foo 1
    ") {
      (types["Foo"] as GenericClassType).instantiate([int32] of TypeVar)
    }
  end

  it "can call overload with generic restriction" do
    assert_type("
      class Foo(T)
      end

      def foo(x : Foo)
        1
      end

      foo(Foo(Int).new)
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
      def foo(x : T, y : T)
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

      def foo(x : Foo(T))
        1
      end

      def foo(x : Int)
        'a'
      end

      x = 1 || Foo(Int).new
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
      def foo(x : Nil | U)
        U
      end

      foo(1 || nil)
      ") { int32.metaclass }
  end

  it "gets free variable from union restriction (2)" do
    assert_type("
      def foo(x : Nil | U)
        U
      end

      foo(nil || 1)
      ") { int32.metaclass }
  end

  it "gets free variable from union restriction without a union" do
    assert_type("
      def foo(x : Nil | U)
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

      def foo(x : Bar(T))
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

      def foo(x : Bar(T))
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

  it "doesn't match tuples of different lengths" do
    assert_error "
      def foo(x : {X, Y, Z})
        'a'
      end

      foo({1, 2})
      ",
      "no overload matches"
  end

  it "matches tuples of different lengths" do
    assert_type("
      def foo(x : {X, Y})
        1
      end

      def foo(x : {X, Y, Z})
        'a'
      end

      x = {1, 2} || {1, 2, 3}
      foo x
      ") { union_of(int32, char) }
  end

  it "matches tuples and uses free var" do
    assert_type("
      def foo(x : {X, Y})
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
end
