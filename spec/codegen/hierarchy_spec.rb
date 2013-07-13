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

  it "codegens non-virtual call that calls virtual call to another virtual call" do
    run(%q(
      class Foo
        def foo
          foo2
        end

        def foo2
          1
        end
      end

      class Bar < Foo
        def bar
          foo
        end
      end

      bar = Bar.new
      bar.bar
      )).to_i.should eq(1)
  end

  it "casts hierarchy type to base hierarchy type" do
    run(%q(
      class Object
        def bar
          1
        end
      end

      class Foo
        def foo
          bar
        end
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new
      f.foo
      )).to_i.should eq(1)
  end

  it "codegens call to Object#to_s from hierarchy type" do
    run(%q(
      require "object"
      require "reference"
      require "string"

      class Foo
      end

      class Bar < Foo
      end

      a = Foo.new || Bar.new
      a.to_s
      ))
  end

  it "codegens call to Object#to_s from nilable type" do
    run(%q(
      require "object"
      require "reference"
      require "nil"
      require "string"

      class Foo
      end

      a = nil || Foo.new
      a.to_s
      ))
  end

  it "codegens virtual call with explicit self" do
    run(%q(
      class Foo
        def foo
          self.bar
        end

        def bar
          1
        end
      end

      class Bar < Foo
      end

      f = Foo.new || Bar.new
      f.foo
      )).to_i.should eq(1)
  end

  it "codegens virtual call with explicit self and nilable type" do
    run(%q(
      class Foo
        def foo
          self.bar
        end

        def bar
          1
        end
      end

      class Bar < Foo
      end

      class Nil
        def foo
          2
        end
      end

      f = Bar.new || nil
      f.foo.to_i
      )).to_i.should eq(1)
  end

  it "initializes ivars to nil even if object never instantiated" do
    run(%q(
      require "prelude"

      class Foo
        def foo
          bar self
        end
      end

      class Bar < Foo
      end

      class Baz < Foo
        def initialize
          @x = Reference.new
        end

        def x
          @x
        end
      end

      def bar(x)
      end

      def bar(x : Baz)
        x.x.to_s
      end

      f = Foo.new || Bar.new
      f.foo
      ))
  end

  it "doesn't lookup in Value+ when hierarchy type is Object+" do
    run(%Q(
      require "reference"

      class Object
        def foo
          !nil?
        end
      end

      class Foo
      end

      a = Foo.new
      a.foo
      )).to_b.should be_true
  end

  it "correctly dispatch call with block when the obj is a hierarchy type" do
    run(%q(
      class Foo
        def each
          yield self
        end

        def foo
          1
        end
      end

      class Bar < Foo
        def foo
          2
        end
      end

      a = Foo.new
      a = Bar.new

      y = 0
      a.each {|x| y = x.foo}
      y
    )).to_i.should eq(2)
  end

  it "dispatch call with nilable hierarchy arg" do
    run(%q(
      class Foo
      end

      class Bar < Foo
      end

      def foo(x)
        1
      end

      def foo(x : Bar)
        2
      end

      def lala
        1 == 2 ? nil : Foo.new || Bar.new
      end

      x = lala
      foo(x)
    )).to_i.should eq(1)
  end
end
