require "../../spec_helper"

describe "Semantic: return" do
  it "infers return type" do
    assert_type("def foo; return 1; end; foo") { int32 }
  end

  it "infers return type with many returns (1)" do
    assert_type("def foo; if true; return 1; end; 'a'; end; foo") { union_of(int32, char) }
  end

  it "infers return type with many returns (2)" do
    assert_type("def foo; if 1 == 1; return 1; end; 'a'; end; foo", inject_primitives: true) { union_of(int32, char) }
  end

  it "errors on return in top level" do
    assert_error "return",
      "can't return from top level"
  end

  it "types return if true" do
    assert_type(%(
      def bar
        return if true
        1
      end

      bar
      )) { nilable int32 }
  end

  it "can use type var as return type (#1226)" do
    assert_type(%(
      module Moo(T)
      end

      class Foo(T)
        def initialize(@x : T)
        end

        def foo : T
          @x
        end
      end

      Foo.new(1).foo
      )) { int32 }
  end

  it "can use type var as return type with an included generic module" do
    assert_type(%(
      module Moo(T)
        def moo : T
          1.5
        end
      end

      class Foo(T)
        include Moo(Float64)

        def initialize(@x : T)
        end
      end

      Foo.new(1).moo
      )) { float64 }
  end

  it "can use type var as return type with an inherited generic class" do
    assert_type(%(
      class Moo(T)
        def moo : T
          1.5
        end
      end

      class Foo(T) < Moo(Float64)
        def initialize(@x : T)
        end
      end

      Foo.new(1).moo
      )) { float64 }
  end

  it "doesn't confuse return type from base class" do
    assert_type(%(
      class Foo
        class Baz
          def foo
            1
          end
        end

        def x : Baz
          Baz.new
        end
      end

      class Bar < Foo
        class Baz
        end
      end

      Bar.new.x.foo
      )) { int32 }
  end

  it "allows returning NoReturn instead of the wanted type" do
    assert_type(%(
      lib LibC
        fun exit : NoReturn
      end

      module Moo
        def bar : Int32
          foo
          1
        end
      end

      class Foo
        include Moo

        def foo
          # Not implemented
          LibC.exit
        end
      end

      foo = Foo.new
      foo.bar
      )) { int32 }
  end

  it "types bug (#1823)" do
    assert_type(%(
      def test
        b = nil

        begin
        rescue
          b ? return 1 : return 2
        end

        b
      end

      test)) { nilable int32 }
  end

  it "allows nilable return type to match subclasses (#1735)" do
    assert_type(%(
      class Foo
      end

      class Bar < Foo
      end

      def test : Foo?
        if true
          Bar.new
        else
          nil
        end
      end

      test
      )) { nilable types["Bar"] }
  end

  it "can use free var in return type (#2492)" do
    assert_type(%(
      def self.demo(a : A, &block : A -> B) : B forall A, B
        block.call(a)
      end

      z = demo(1) do |x|
        x.to_f
      end
      z
      ), inject_primitives: true) { float64 }
  end

  it "can use non-type free var in return type (#6543)" do
    assert_type(<<-CRYSTAL) { generic_class "Foo", 1.int32 }
      class Foo(A)
      end

      def foo(a : Foo(P)) : Foo(P) forall P
        a
      end

      foo(Foo(1).new)
      CRYSTAL
  end

  it "can use non-type free var in return type (2) (#6543)" do
    assert_type(<<-CRYSTAL) { generic_class "Matrix", 3.int32, 4.int32 }
      class Matrix(N, M)
        def *(other : Matrix(M, P)) : Matrix(N, P) forall P
          Matrix(N, P).new
        end
      end

      Matrix(3, 2).new * Matrix(2, 4).new
      CRYSTAL
  end

  it "errors if non-type free var cannot be inferred" do
    assert_error <<-CRYSTAL, "undefined constant P"
      class Foo(A)
      end

      def foo(a) : Foo(P) forall P
        a
      end

      foo(Foo(1).new)
      CRYSTAL
  end

  it "forms a tuple from multiple return values" do
    assert_type("def foo; return 1, 1.0; end; foo") { tuple_of([int32, float64]) }
  end

  it "flattens splats inside multiple return values" do
    assert_type("def foo; return 1, *{1.0, 'a'}, true; end; foo") { tuple_of([int32, float64, char, bool]) }
  end
end
