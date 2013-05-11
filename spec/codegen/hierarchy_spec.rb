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
end