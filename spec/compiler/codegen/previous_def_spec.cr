require "../../spec_helper"

describe "codegen: previous_def" do
  it "codegens previous def" do
    run(%(
      def foo
        1
      end

      def foo
        previous_def + 1
      end

      foo
      )).to_i.should eq(2)
  end

  it "codeges previous def when inside fun and forwards args" do
    run(%(
      def foo(z)
        z + 1
      end

      def foo(z)
        ->(x : Int32) { x + previous_def }
      end

      x = foo(2)
      x.call(3)
      )).to_i.should eq(6)
  end

  it "codegens previous def when inside fun with self" do
    run(%(
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
      )).to_i.should eq(1)
  end
end
