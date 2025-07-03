require "../../spec_helper"

describe "Semantic: hooks" do
  it "does inherited macro" do
    assert_type("
      class Foo
        macro inherited
          def self.{{@type.name.downcase.id}}
            1
          end
        end
      end

      class Bar < Foo
      end

      Bar.bar
      ") { int32 }
  end

  it "does included macro" do
    assert_type("
      module Foo
        macro included
          def self.{{@type.name.downcase.id}}
            1
          end
        end
      end

      class Bar
        include Foo
      end

      Bar.bar
      ") { int32 }
  end

  it "does extended macro" do
    assert_type("
      module Foo
        macro extended
          def self.{{@type.name.downcase.id}}
            1
          end
        end
      end

      class Bar
        extend Foo
      end

      Bar.bar
      ") { int32 }
  end

  it "does added method macro" do
    assert_type("
      class Foo
        macro method_added(d)
          def self.{{d.name.downcase.id}}
            1
          end
        end

        def foo; end
      end

      Foo.foo
      ") { int32 }
  end

  it "does not invoke 'method_added' hook recursively" do
    assert_type("
      class Foo
        macro method_added(d)
          def {{d.name.id}}
            1
          end
        end

        def foo
          nil
        end
      end

      Foo.new.foo
      ") { int32 }
  end

  it "errors if wrong inherited params size" do
    assert_error %(
      class Foo
        macro inherited(x)
        end
      end
      ), "wrong number of parameters for macro 'inherited' (given 1, expected 0)"
  end

  it "errors if wrong included params size" do
    assert_error %(
      module Foo
        macro included(x)
        end
      end
      ), "wrong number of parameters for macro 'included' (given 1, expected 0)"
  end

  it "errors if wrong extended params size" do
    assert_error %(
      module Foo
        macro extended(x)
        end
      end
      ), "wrong number of parameters for macro 'extended' (given 1, expected 0)"
  end

  it "types initializer in inherited" do
    assert_type(%(
      abstract class Foo
        macro inherited
          @@bar = new

          def self.bar
            @@bar
          end
        end
      end

      class Bar < Foo
        def initialize(@name = "foo")
        end

        def name
          @name
        end
      end

      Bar.bar.name
      )) { string }
  end

  it "errors if wrong extended params length" do
    assert_error %(
      class Foo
        macro method_added
        end
      end
      ), "wrong number of parameters for macro 'method_added' (given 0, expected 1)"
  end

  it "includes error message in included hook (#889)" do
    assert_error %(
      module Doable
        macro included
          def {{@type.name.unknown}}
            "woo!"
          end
        end
      end

      class BobWaa
        include Doable
      end
      ),
      "undefined macro method 'MacroId#unknown'"
  end

  it "does included macro for generic module" do
    assert_type(%(
      module Mod(T)
        macro included
          def self.method
            1
          end
        end
      end

      class Klass
        include Mod(Nil)
      end

      Klass.method
      )) { int32 }
  end

  it "does inherited macro for generic class" do
    assert_type(%(
      class Foo(T)
        macro inherited
          def self.method
            1
          end
        end
      end

      class Klass < Foo(Int32)
      end

      Klass.method
      )) { int32 }
  end

  it "errors if wrong finished params length" do
    assert_error %(
      class Foo
        macro finished(x)
        end
      end
      ), "wrong number of parameters for macro 'finished' (given 1, expected 0)"
  end

  it "types macro finished hook bug regarding initialize (#3964)" do
    assert_type(%(
      class A1
        macro finished
          @x : String
          def initialize(@x)
          end

          def x; @x; end
        end
      end

      class A2
        macro finished
          @y : Int32
          def initialize(@y)
          end

          def y; @y; end
        end
      end

      a1 = A1.new("x")
      a2 = A2.new(1)
      {a1.x, a2.y}
      )) { tuple_of([string, int32]) }
  end

  it "does inherited macro through generic instance type (#9693)" do
    assert_type("
      class Foo(X)
        macro inherited
          def self.{{@type.name.downcase.id}}
            1
          end
        end
      end

      class Bar < Foo(Int32)
      end

      class Baz < Bar
      end

      Baz.baz
      ") { int32 }
  end
end
