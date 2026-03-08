require "../../spec_helper"

describe "Semantic: hooks" do
  it "does inherited macro" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "does included macro" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "does extended macro" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "does added method macro" do
    assert_type(<<-CRYSTAL) { int32 }
      class Foo
        macro method_added(d)
          def self.{{d.name.downcase.id}}
            1
          end
        end

        def foo; end
      end

      Foo.foo
      CRYSTAL
  end

  it "does not invoke 'method_added' hook recursively" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "errors if wrong inherited params size" do
    assert_error <<-CRYSTAL, "wrong number of parameters for macro 'inherited' (given 1, expected 0)"
      class Foo
        macro inherited(x)
        end
      end
      CRYSTAL
  end

  it "errors if wrong included params size" do
    assert_error <<-CRYSTAL, "wrong number of parameters for macro 'included' (given 1, expected 0)"
      module Foo
        macro included(x)
        end
      end
      CRYSTAL
  end

  it "errors if wrong extended params size" do
    assert_error <<-CRYSTAL, "wrong number of parameters for macro 'extended' (given 1, expected 0)"
      module Foo
        macro extended(x)
        end
      end
      CRYSTAL
  end

  it "types initializer in inherited" do
    assert_type(<<-CRYSTAL) { string }
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
      CRYSTAL
  end

  it "errors if wrong extended params length" do
    assert_error <<-CRYSTAL, "wrong number of parameters for macro 'method_added' (given 0, expected 1)"
      class Foo
        macro method_added
        end
      end
      CRYSTAL
  end

  it "includes error message in included hook (#889)" do
    assert_error <<-CRYSTAL, "undefined macro method 'MacroId#unknown'"
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
      CRYSTAL
  end

  it "does included macro for generic module" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "does inherited macro for generic class" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end

  it "errors if wrong finished params length" do
    assert_error <<-CRYSTAL, "wrong number of parameters for macro 'finished' (given 1, expected 0)"
      class Foo
        macro finished(x)
        end
      end
      CRYSTAL
  end

  it "types macro finished hook bug regarding initialize (#3964)" do
    assert_type(<<-CRYSTAL) { tuple_of([string, int32]) }
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
      CRYSTAL
  end

  it "does inherited macro through generic instance type (#9693)" do
    assert_type(<<-CRYSTAL) { int32 }
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
      CRYSTAL
  end
end
