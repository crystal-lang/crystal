require "../../spec_helper"

describe "Semantic: nilable instance var" do
  it "says instance var was not initialized in all of the initialize methods" do
    assert_error <<-CRYSTAL, "this 'initialize' doesn't explicitly initialize instance variable '@foo' of Foo, rendering it nilable"
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
      CRYSTAL
  end

  it "says instance var was not initialized in all of the initialize methods (2)" do
    assert_error <<-CRYSTAL, "can't infer the type of instance variable '@foo' of Foo", inject_primitives: true
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
      CRYSTAL
  end

  it "says instance var was not initialized in all of the initialize methods, with var declaration" do
    assert_error <<-CRYSTAL, "instance variable '@foo' of Foo was not initialized directly in all of the 'initialize' methods, rendering it nilable. Indirect initialization is not supported."
      class Foo
        @foo : Int32

        def foo
          @foo
        end
      end

      Foo.new.foo
      CRYSTAL
  end

  it "says instance var was used before initialized" do
    assert_error <<-CRYSTAL, "Instance variable '@foo' was used before it was initialized in one of the 'initialize' methods, rendering it nilable"
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
      CRYSTAL
  end

  it "says instance var was used before initialized (2)" do
    assert_error <<-CRYSTAL, "Instance variable '@foo' was used before it was initialized in one of the 'initialize' methods, rendering it nilable"
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
      CRYSTAL
  end

  it "says self was used before instance var was initialized" do
    assert_error <<-CRYSTAL, "'self' was used before initializing instance variable '@foo', rendering it nilable"
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
      CRYSTAL
  end

  it "says self was used before instance var was initialized (2)" do
    assert_error <<-CRYSTAL, "'self' was used before initializing instance variable '@foo', rendering it nilable"
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
      CRYSTAL
  end

  it "says self was used before instance var was initialized (3)" do
    assert_error <<-CRYSTAL, "'self' was used before initializing instance variable '@foo', rendering it nilable"
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
      CRYSTAL
  end

  it "finds type that doesn't initialize instance var (#1222)" do
    assert_error <<-CRYSTAL, "this 'initialize' doesn't initialize instance variable '@x' of Base, with Unreferenced < Base, rendering it nilable"
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
      CRYSTAL
  end

  it "doesn't consider as nil if initialized with catch-all" do
    assert_type(<<-CRYSTAL, inject_primitives: true) { int32 }
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
      CRYSTAL
  end

  it "marks instance var as nilable if assigned inside captured block (#1696)" do
    assert_error <<-CRYSTAL, "Instance variable '@foo' was used before it was initialized in one of the 'initialize' methods, rendering it nilable"
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
      CRYSTAL
  end

  it "marks instance var as nilable if assigned inside proc literal" do
    assert_error <<-CRYSTAL, "Instance variable '@foo' was used before it was initialized in one of the 'initialize' methods, rendering it nilable"
      class Foo
        def initialize
          ->{ @foo = 1 }
        end

        def foo
          @foo
        end
      end

      Foo.new.foo
      CRYSTAL
  end
end
