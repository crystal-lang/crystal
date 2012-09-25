require 'spec_helper'

describe 'Code gen: class' do
  it "codegens instace method" do
    run('class Foo; def coco; 1; end; end; Foo.new.coco').to_i.should eq(1)
  end

  it "codegens instance var" do
  	run(%Q(
			class Foo
        #{rw 'coco'}
			end

			f = Foo.new
			f.coco = 2

			g = Foo.new
			g.coco = 0.5

			f.coco + g.coco
  		)).to_f.should eq(2.5)
  end

  it "codegens recursive type" do
    run(%Q(
      class Foo
        #{rw 'next'}
      end

      f = Foo.new
      f.next = f
      ))
  end

  it "codegens method call of instance var" do
    run(%Q(
      class List
        def foo
          @last = 1
          @last.to_f
        end
      end

      l = List.new
      l.foo
      )).to_f.should eq(1.0)
  end
end
