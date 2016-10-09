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

  it "errors if wrong inherited args size" do
    assert_error %(
      class Foo
        macro inherited(x)
        end
      end
      ), "macro 'inherited' must not have arguments"
  end

  it "errors if wrong included args size" do
    assert_error %(
      module Foo
        macro included(x)
        end
      end
      ), "macro 'included' must not have arguments"
  end

  it "errors if wrong extended args size" do
    assert_error %(
      module Foo
        macro extended(x)
        end
      end
      ), "macro 'extended' must not have arguments"
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

  it "errors if wrong extended args length" do
    assert_error %(
      class Foo
        macro method_added
        end
      end
      ), "macro 'method_added' must have a argument"
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
end
