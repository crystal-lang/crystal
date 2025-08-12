require "../../spec_helper"

describe "Code gen: def with default value" do
  it "codegens def with one default value" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo(x = 1)
        x
      end

      foo
      CRYSTAL
  end

  it "codegens def new with one default value" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def initialize(@x = 1)
        end

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "considers first the one with more arguments" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo(x, y = 1)
        1
      end

      def foo(x, y : String)
        2
      end

      foo 1, "hello"
      CRYSTAL
  end

  it "considers first the one with a restriction" do
    run(<<-CRYSTAL).to_i.should eq(1)
      def foo(x : String, y = "")
        1
      end

      def foo(x, y)
        2
      end

      foo "hello"
      CRYSTAL
  end

  it "doesn't mix types of instance vars with initialize and new" do
    assert_type(%(
      class Foo
        def initialize(x = 1)
          @x = x
        end

        def self.new(x : String)
          new(1)
        end

        def x
          @x
        end
      end

      Foo.new
      Foo.new(1)
      Foo.new("hello").x
      )) { int32 }
  end

  it "resolves expanded call to current type, not to virtual type" do
    assert_type(%(
      class Foo
        def foo(x = 1)
          2
        end
      end

      class Bar < Foo
        def foo(x)
          'a'
        end
      end

      bar = Bar.new
      bar.foo
      )) { int32 }
  end
end
