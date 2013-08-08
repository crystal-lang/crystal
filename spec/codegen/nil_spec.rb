require 'spec_helper'

describe 'Code gen: nil' do
  it "codegens empty program" do
    run('')
  end

  it "codegens nil? for Reference gives false" do
    run('require "reference"; Reference.new.nil?').to_b.should be_false
  end

  it "codegens nil? for Reference gives true" do
    run(%Q(
      require "nil"
      require "reference"

      class Foo
        def initialize
          if 1 == 2
            @x = Reference.new
          end
          1
        end

        def x
          @x
        end
      end

      Foo.new.x.nil?
      )).to_b.should be_true
  end

  it "codegens nil? for primitives gives false" do
    run("0.nil?").to_b.should be_false
  end

  it "codegens nilable dispatch" do
    run(%q(
      def foo(x)
        x
      end

      a = nil
      a = "foo"

      foo(a)
      )).to_string.should eq('foo')
  end

  it "codegens nilable dispatch with obj nilable" do
    run(%q(
      class Nil
        def foo
          1
        end
      end

      class Foo
        def foo
          2
        end
      end

      a = Foo.new
      a = nil
      a.foo
      )).to_i.should eq(1)
  end

  it "codegens nilable dispatch with obj nilable 2" do
    run(%q(
      class Nil
        def foo
          1
        end
      end

      class Foo
        def foo
          2
        end
      end

      a = nil
      a = Foo.new
      a.foo
      )).to_i.should eq(2)
  end

  it "codegens nilable dispatch with arg nilable" do
    run(%q(
      def foo(x : Object)
        1
      end

      def foo(x : Nil)
        2
      end

      a = Reference.new
      a = nil
      foo(a)
      )).to_i.should eq(2)
  end

  it "codegens nilable dispatch with arg nilable 2" do
    run(%q(
      def foo(x : Object)
        1
      end

      def foo(x : Nil)
        2
      end

      a = nil
      a = Reference.new
      foo(a)
      )).to_i.should eq(1)
  end

  it "assigns nilable to union" do
    run(%q(
      a = nil
      a = "foo"
      a = Reference.new

      b = nil
      b = "foo"

      a = b
      )).to_string.should eq('foo')
  end

  it "codegens nil instance var" do
    run(%q(
      class Foo
        def bar
          @x
        end
      end

      f = Foo.new
      f.bar
      ))
  end

  it "codegens nil by default for uninitialized instance variables" do
    run(%q(
      require "nil"
      require "reference"

      class Foo
        def bar
          a = @x.nil?
          @x = 1
          a
        end
      end

      f = Foo.new
      f.bar ? 1 : 2)).to_i.should eq(1)
  end

  it "codegens nilable dispatch with boxing" do
    run(%q(
      require "prelude"
      
      class Object
        def should(expectation)
          expectation.match self
        end
      end

      class EqualExpectation(T)
        def initialize(value : T)
          @value = value
        end

        def match(value)
          value == @value
        end
      end

      def eq(value)
        EqualExpectation.new value
      end

      a = Reference.new || nil
      a.should eq(nil)
      ))
  end
end
