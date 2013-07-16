require 'spec_helper'

describe 'Code gen: class' do
  it "codegens instace method with allocate" do
    run('class Foo; def coco; 1; end; end; Foo.allocate.coco').to_i.should eq(1)
  end

  it "codegens instace method with new and instance var" do
    run('class Foo; def initialize; @coco = 2; end; def coco; @coco = 1; @coco; end; end; f = Foo.new; f.coco').to_i.should eq(1)
  end

  it "codegens instace method with new" do
    run('class Foo; def coco; 1; end; end; Foo.new.coco').to_i.should eq(1)
  end

  it "codegens call to same instance" do
    run('class Foo; def foo; 1; end; def bar; foo; end; end; Foo.new.bar').to_i.should eq(1)
  end

  it "codegens instance var" do
    run(%Q(
      class Foo(T)
        def initialize(coco : T)
          @coco = coco
        end
        def coco
          @coco
        end
      end

      f = Foo(Int).new(2)
      g = Foo(Float).new(0.5_f32)
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
        def initialize
          @last = 0
        end

        def foo
          @last = 1
          @last.to_f
        end
      end

      l = List.new
      l.foo
      )).to_f.should eq(1.0)
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

  it "codegens virtual call that calls another method" do
    run(%Q(
      class Foo
        def foo
          foo2
        end

        def foo2
          1
        end
      end

      class Bar < Foo
      end

      Bar.new.foo
      )).to_i.should eq(1)
  end

  it "codgens virtual method of generic class" do
    run(%Q(
      require "char"

      class Object
        def foo
          bar
        end

        def bar
          'a'
        end
      end

      class Foo(T)
        def bar
          1
        end
      end

      Foo(Int32).new.foo.to_i
      )).to_i.should eq(1)
  end

  it "changes instance variable in method (ssa bug)" do
    run(%q(
      class Foo
        def initialize
          @var = 0
        end

        def foo
          @var = 1
          bar
          @var
        end

        def bar
          @var = 2
        end
      end

      foo = Foo.new
      foo.foo
      )).to_i.should eq(2)
  end
end
