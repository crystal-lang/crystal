require "../../spec_helper"

describe "Type inference: return" do
  it "infers return type" do
    assert_type("def foo; return 1; end; foo") { int32 }
  end

  it "infers return type with many returns (1)" do
    assert_type("def foo; if true; return 1; end; 'a'; end; foo") { int32 }
  end

  it "infers return type with many returns (2)" do
    assert_type("def foo; if 1 == 1; return 1; end; 'a'; end; foo") { union_of(int32, char) }
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
      )) { |mod| mod.nil }
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
      )) { no_return }
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
end
