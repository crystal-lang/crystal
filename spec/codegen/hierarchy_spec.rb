require 'spec_helper'

describe 'Code gen: hierarchy type' do
  it "call base method" do
    run(%q(
      class Foo
        def coco
          1
        end
      end

      class Bar < Foo
      end

      a = Foo.new
      a = Bar.new
      a.coco
    )).to_i.should eq(1)
  end

  it "call overwritten method" do
    run(%q(
      class Foo
        def coco
          1
        end
      end

      class Bar < Foo
        def coco
          2
        end
      end

      a = Foo.new
      a = Bar.new
      a.coco
    )).to_i.should eq(2)
  end

  it "call base overwritten method" do
    run(%q(
      class Foo
        def coco
          1
        end
      end

      class Bar < Foo
        def coco
          2
        end
      end

      a = Bar.new
      a = Foo.new
      a.coco
    )).to_i.should eq(1)
  end

  it "dispatch call with hierarchy type argument" do
    run(%q(
      class Foo
      end

      class Bar < Foo
      end

      def coco(x : Bar)
        1
      end

      def coco(x)
        2
      end

      a = Bar.new
      a = Foo.new
      coco(a)
    )).to_i.should eq(2)
  end

  it "can belong to union" do
    run(%q(
      class Foo
        def foo; 1; end
      end
      class Bar < Foo; end
      class Baz
        def foo; 2; end
      end

      x = Foo.new
      x = Bar.new
      x = Baz.new
      x.foo
    )).to_i.should eq(2)
  end

  it "lookup instance variables in parent types" do
    run(%q(
      class Foo
        def initialize
          @x = 1
        end
        def foo
          @x
        end
      end

      class Bar < Foo
        def foo
          @x + 1
        end
      end

      a = Bar.new || Foo.new
      a.foo
    )).to_i.should eq(2)
  end

  it "assign instance variable in hierarchy type" do
    run(%q(
      class Foo
        def foo
          @x = 1
        end
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new
      f.foo
    )).to_i.should eq(1)
  end
end