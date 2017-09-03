require "../../spec_helper"

describe "Semantic: nilable instance var" do
  it "says instance var was not initialized in all of the initialize methods" do
    assert_error %(
      class Foo
        def initialize
          @foo = 1
        end

        def initialize(other)
        end

        def foo
          @foo
        end
      end

      Foo.new.foo + 1
      ),
      "this 'initialize' doesn't explicitly initialize instance variable '@foo' of Foo, rendering it nilable"
  end

  it "says instance var was not initialized in all of the initialize methods (2)" do
    assert_error %(
      abstract class Foo
        def foo
          @foo
        end
      end

      class Bar < Foo
        def initialize
          @foo = 1
        end
      end

      class Baz < Foo
      end

      p = Pointer(Foo).malloc(1_u64)
      p.value = Bar.new
      p.value = Baz.new
      p.value.foo + 1
      ),
      "Can't infer the type of instance variable '@foo' of Foo"
  end

  it "says instance var was not initialized in all of the initialize methods, with var declaration" do
    assert_error %(
      class Foo
        @foo : Int32

        def foo
          @foo
        end
      end

      Foo.new.foo
      ),
      "instance variable '@foo' of Foo was not initialized directly in all of the 'initialize' methods, rendering it nilable. Indirect initialization is not supported."
  end

  it "says instance var was used before initialized" do
    assert_error %(
      class Foo
        def initialize
          @foo
          @foo = 1
        end

        def foo
          @foo
        end
      end

      Foo.new.foo + 1
      ),
      "instance variable '@foo' was used before it was initialized in one of the 'initialize' methods, rendering it nilable"
  end

  it "says instance var was used before initialized (2)" do
    assert_error %(
      class Foo
        def initialize
          foo
          @foo = 1
        end

        def foo
          @foo
        end
      end

      Foo.new.foo + 1
      ),
      "instance variable '@foo' was used before it was initialized in one of the 'initialize' methods, rendering it nilable"
  end

  it "says self was used before instance var was initialized" do
    assert_error %(
      def baz(x)
      end

      class Foo
        def initialize
          baz(self)
          @foo = 1
        end

        def foo
          @foo
        end
      end

      Foo.new.foo + 1
      ),
      "'self' was used before initializing instance variable '@foo', rendering it nilable"
  end

  it "says self was used before instance var was initialized (2)" do
    assert_error %(
      class Baz
        def self.baz(x)
        end
      end

      class Foo
        def initialize
          Baz.baz(self)
          @foo = 1
        end

        def foo
          @foo
        end
      end

      Foo.new.foo + 1
      ),
      "'self' was used before initializing instance variable '@foo', rendering it nilable"
  end

  it "says self was used before instance var was initialized (3)" do
    assert_error %(
      class Foo
        def initialize
          a = self
          @foo = 1
        end

        def foo
          @foo
        end
      end

      Foo.new.foo + 1
      ),
      "'self' was used before initializing instance variable '@foo', rendering it nilable"
  end

  it "finds type that doesn't initialize instance var (#1222)" do
    assert_error %(
      class Base
        def initialize
          @x = 0
        end
      end

      class Unreferenced < Base
        def initialize
          # missing super
        end
      end

      class Derived < Base
        def initialize
          super
        end

        def use_x
          @x + 100
        end
      end

      Derived.new.use_x
      ),
      "this 'initialize' doesn't initialize instance variable '@x' of Base, with Unreferenced < Base, rendering it nilable"
  end

  it "doesn't consider as nil if initialized with catch-all" do
    assert_type(%(
      class Test
        @a = 0

        def initialize
          @a + 1
        end

        def a
          @a
        end
      end

      Test.new.a
      )) { int32 }
  end

  it "marks instance var as nilable if assigned inside captured block (#1696)" do
    assert_error %(
      def capture(&block)
        block
      end

      class Foo
        def initialize
          capture { @foo = 1 }
        end

        def foo
          @foo
        end
      end

      Foo.new.foo
      ),
      "instance variable '@foo' was used before it was initialized in one of the 'initialize' methods, rendering it nilable"
  end

  it "marks instance var as nilable if assigned inside proc literal" do
    assert_error %(
      class Foo
        def initialize
          ->{ @foo = 1 }
        end

        def foo
          @foo
        end
      end

      Foo.new.foo
      ),
      "instance variable '@foo' was used before it was initialized in one of the 'initialize' methods, rendering it nilable"
  end
end
