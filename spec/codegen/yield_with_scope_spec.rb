require 'spec_helper'

describe 'Type inference: yield with scope' do
  it "uses scope in global method" do
    run(%(
      require "int"
      def foo; 1.yield; end

      foo do
        succ
      end
    )).to_i.should eq(2)
  end

  it "uses scope in instance method" do
    run(%(
      require "int"
      def foo; 1.yield; end

      class Foo
        def test
          foo do
            succ
          end
        end

        def succ
          10
        end
      end

      Foo.new.test
    )).to_i.should eq(2)
  end

  it "it uses self for instance method" do
    run(%(
      require "int"
      def foo; 1.yield; end

      class Foo
        def test
          foo do
            self.succ
          end
        end

        def succ
          10
        end
      end

      Foo.new.test
    )).to_i.should eq(10)
  end
end
