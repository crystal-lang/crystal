require 'spec_helper'

describe 'Code gen: block' do
  it "generate inline" do
    run(%q(
      def foo
        yield
      end

      foo do
        1
      end
    )).to_i.should eq(1)
  end

  it "pass yield arguments" do
    run(%q(
      def foo
        yield 1
      end

      foo do |x|
        x + 1
      end
    )).to_i.should eq(2)
  end

  it "pass arguments to yielder function" do
    run(%q(
      def foo(a)
        yield a
      end

      foo(3) do |x|
        x + 1
      end
    )).to_i.should eq(4)
  end

  it "pass self to yielder function" do
    run(%q(
      class Int
        def foo
          yield self
        end
      end

      3.foo do |x|
        x + 1
      end
    )).to_i.should eq(4)
  end

  it "pass self and arguments to yielder function" do
    run(%q(
      class Int
        def foo(i)
          yield self, i
        end
      end

      3.foo(2) do |x, i|
        x + i
      end
    )).to_i.should eq(5)
  end
end
