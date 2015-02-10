require "../../spec_helper"

describe "Type inference: nilable instance var" do
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
      "instance variable '@foo' was not initialized in all of the 'initialize' methods, rendering it nilable"
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
end
