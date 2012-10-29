require 'spec_helper'

describe 'Code gen: class' do
  it "codegens instace method with alloc" do
    run('class Foo; def coco; 1; end; end; Foo.alloc.coco').to_i.should eq(1)
  end

  it "codegens instace method with alloc and instance var" do
    run('class Foo; def coco; @coco = 1; @coco; end; end; f = Foo.alloc; f.coco').to_i.should eq(1)
  end

  it "codegens instace method with new" do
    run('class Foo; def coco; 1; end; end; Foo.new.coco').to_i.should eq(1)
  end

  it "codegens call to same instance" do
    run('class Foo; def foo; 1; end; def bar; foo; end; end; Foo.new.bar').to_i.should eq(1)
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

  it "codegens method call that create instances" do
    run(%Q(
      class Foo
        #{rw :value}
      end

      def gen
        Foo.new
      end

      f = gen
      f.value = 1
      f.value
    )).to_i.should eq(1)
  end

  it "codegens new which calls initialize" do
    run(%Q(
      class Foo
        def initialize(value)
          @value = value
        end

        def value
          @value
        end
      end

      f = Foo.new 1
      f.value
    )).to_i.should eq(1)
  end

  it "codegens instance with union instance var" do
    run(%Q(
      class A
        #{rw :next}
      end

      a = A.new
      a.next = 1

      a = A.new
      a.next = 2.5
      a.next.to_f
    )).to_f.should eq(2.5)
  end

  it "codegens method from another method without obj and accesses instance vars" do
    run(%Q(
      class Foo
        def foo
          bar
        end

        def bar
          @a = 1
        end
      end

      f = Foo.new
      f.foo
      )).to_i.should eq(1)
  end
end
