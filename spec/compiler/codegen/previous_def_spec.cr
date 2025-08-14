require "../../spec_helper"

describe "codegen: previous_def" do
  it "codegens previous def" do
    run(<<-CRYSTAL).to_i.should eq(2)
      def foo
        1
      end

      def foo
        previous_def &+ 1
      end

      foo
      CRYSTAL
  end

  it "codegens previous def when inside fun and forwards args" do
    run(<<-CRYSTAL).to_i.should eq(6)
      def foo(z)
        z &+ 1
      end

      def foo(z)
        ->(x : Int32) { x &+ previous_def }
      end

      x = foo(2)
      x.call(3)
      CRYSTAL
  end

  it "codegens previous def when inside fun with self" do
    run(<<-CRYSTAL).to_i.should eq(1)
      class Foo
        def initialize
          @x = 1
        end

        def bar
          @x
        end
      end

      class Foo
        def bar
          x = ->{ previous_def }
        end
      end

      Foo.new.bar.call
      CRYSTAL
  end

  it "correctly passes named arguments" do
    run(<<-CRYSTAL).to_i.should eq(4)
      def foo(x, *args, other = 1)
        other
      end

      def foo(x, *args, other = 1)
        previous_def
      end

      foo(1, 2, 3, other: 4)
      CRYSTAL
  end
end
