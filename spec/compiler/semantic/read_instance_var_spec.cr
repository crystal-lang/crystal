require "../../spec_helper"

describe "Semantic: read instance var" do
  it "can read from same class" do
    assert_type(%(
      class Foo
        @x = 1

        def foo(other)
          other.@x
        end
      end

      Foo.new.foo(Foo.new)
      )) { int32 }
  end

  it "can read from subclass" do
    assert_type(%(
      class Foo
        @x = 1

        def foo(other)
          other.@x
        end
      end

      class Bar < Foo
      end

      Foo.new.foo(Bar.new)
      )) { int32 }
  end

  it "can read from superclass" do
    assert_type(%(
      class Foo
        @x = 1
      end

      class Bar < Foo
        def foo(other)
          other.@x
        end
      end

      Bar.new.foo(Foo.new)
      )) { int32 }
  end

  it "can read from different instantiations of a generic type" do
    assert_type(%(
      class Foo(T)
        @x = 1

        def read(other)
          other.@x
        end
      end

      Foo(Int32).new.read(Foo(Bool).new)
      )) { int32 }
  end

  it "can't read from unrelated type in same namespace" do
    assert_error %(
      module Moo
        class Foo
          @x = 1

          def foo(other)
            other.@x
          end
        end

        class Bar
          @x = 2
        end
      end

      Moo::Foo.new.foo(Moo::Bar.new)
      ),
      "can't access Moo::Bar.@x from unrelated type Moo::Foo"
  end

  it "can't read from unrelated type" do
    assert_error %(
      class Foo
        @x = 1

        def foo(other)
          other.@x
        end
      end

      class Bar
        @x = 2
      end

      Foo.new.foo(Bar.new)
      ),
      "can't access Bar.@x from unrelated type Foo"
  end

  it "can't read from top-level" do
    assert_error %(
      class Foo
        @x = 1
      end

      Foo.new.@x
      ),
      "can't access Foo.@x from the top-level"
  end

  it "reads a virtual type instance var" do
    run(%(
      class Foo
        def initialize(@x : Int32)
        end

        def self.read_x(foo)
          foo.@x
        end
      end

      class Bar < Foo
      end

      foo = Foo.new(1) || Bar.new(2)
      Foo.read_x(foo)
      )).to_i.should eq(1)
  end

  it "errors if reading non-existent ivar" do
    assert_error %(
      class Foo
        def self.read(foo)
          foo.@y
        end
      end

      foo = Foo.new
      Foo.read(foo)
      ),
      "Can't infer the type of instance variable '@y' of Foo"
  end
end
