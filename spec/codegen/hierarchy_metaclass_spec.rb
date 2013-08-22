require 'spec_helper'

describe 'Code gen: hierarchy type metaclass' do
  it "codegens call 1" do
    run(%q(
      class Foo
        def self.foo
          1
        end
      end

      class Bar < Foo
        def self.foo
          2
        end
      end

      f = Foo.new || Bar.new
      f.class.foo
    )).to_i.should eq(1)
  end

  it "codegens call 2" do
    run(%q(
      class Foo
        def self.foo
          1
        end
      end

      class Bar < Foo
        def self.foo
          2
        end
      end

      f = Bar.new || Foo.new
      f.class.foo
    )).to_i.should eq(2)
  end

  it "codegens allocate 1" do
    run(%q(
      class Foo
        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          2
        end
      end

      f = Foo.new || Bar.new
      f.class.new.foo
    )).to_i.should eq(1)
  end

  it "codegens allocate 2" do
    run(%q(
      class Foo
        def foo
          2
        end
      end

      class Bar < Foo
        def foo
          1
        end
      end

      f = Foo.new || Bar.new
      f.class.new.foo
    )).to_i.should eq(2)
  end
end
