require "../../spec_helper"

describe "Codegen: super" do
  it "codegens super without arguments" do
    run("class Foo; def foo; 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo").to_i.should eq(1)
  end

  it "codegens super without arguments but parent has arguments" do
    run("class Foo; def foo(x); x + 1; end; end; class Bar < Foo; def foo(x); super; end; end; Bar.new.foo(1)").to_i.should eq(2)
  end

  it "codegens super without arguments and instance variable" do
    run("class Foo; def foo; @x = 1; end; end; class Bar < Foo; def foo; super; end; end; Bar.new.foo").to_i.should eq(1)
  end

  it "codegens super that calls subclass method" do
    run("
      class Foo
        def foo
          bar
        end

        def bar
          1
        end
      end

      class Bar < Foo
        def foo
          super
        end

        def bar
          2
        end
      end

      b = Bar.new
      b.foo
      ").to_i.should eq(2)
  end

  it "codegens super that calls subclass method 2" do
    run("
      class Foo
        def foo
          self.bar
        end

        def bar
          1
        end
      end

      class Bar < Foo
        def foo
          super
        end

        def bar
          2
        end
      end

      b = Bar.new
      b.foo
      ").to_i.should eq(2)
  end

  it "codegens super that calls subclass method 3" do
    run("
      class Foo
        def foo
          self.bar
        end

        def bar
          1
        end
      end

      class Bar < Foo
        def foo
          super
        end

        def bar
          2
        end
      end

      b = Foo.new || Bar.new
      b.foo
      ").to_i.should eq(1)
  end

  it "codegens super that calls subclass method 4" do
    run("
      class Foo
        def foo
          self.bar
        end

        def bar
          1
        end
      end

      class Bar < Foo
        def foo
          super
        end

        def bar
          2
        end
      end

      b = Bar.new || Foo.new
      b.foo
      ").to_i.should eq(2)
  end

  it "codegens super that calls subclass method 5" do
    run("
      module Mod
        def add_def
          another
        end
      end

      abstract class ClassType
        include Mod

        def add_def
          super
        end
      end

      class NonGenericClassType < ClassType
      end

      class PrimitiveType < ClassType
        def another
          2
        end
      end

      class IntegerType < PrimitiveType
        def another
          3
        end
      end

      c = PrimitiveType.new || IntegerType.new
      c.add_def
      ").to_i.should eq(2)
  end

  it "codegens super that calls subclass method 6" do
    run("
      module Mod
        def add_def
          another
        end
      end

      abstract class ClassType
        include Mod

        def add_def
          super
        end
      end

      class NonGenericClassType < ClassType
      end

      class PrimitiveType < ClassType
        def another
          2
        end
      end

      class IntegerType < PrimitiveType
        def another
          3
        end
      end

      c = IntegerType.new || PrimitiveType.new
      c.add_def
      ").to_i.should eq(3)
  end

  it "codegens super inside closure" do
    run(%(
      class Foo
        def initialize(@x)
        end

        def foo
          @x
        end
      end

      class Bar < Foo
        def foo
          ->{ super }
        end
      end

      f = Bar.new(1).foo
      f.call
      )).to_i.should eq(1)
  end

  it "codegens super inside closure forwarding args" do
    run(%(
      class Foo
        def initialize(@x)
        end

        def foo(z)
          z + @x
        end
      end

      class Bar < Foo
        def foo(z)
          ->(x : Int32) { x + super }
        end
      end

      f = Bar.new(1).foo(2)
      f.call(3)
      )).to_i.should eq(6)
  end

  it "build super on generic class (bug)" do
    codegen(%(
      class Base
        def foo(x)
          1.5
        end
      end

      class Foo(T) < Base
        def foo
          super(1)
        end
      end

      Foo(Int32).new.foo
      ))
  end

  it "calls super in module method (#556)" do
    run(%(
      class Parent
        def a
          1
        end
      end

      module Mod
        def a
          super
        end
      end

      class Child < Parent
        include Mod
      end

      Child.new.a
      )).to_i.should eq(1)
  end

  it "calls super in generic module method" do
    run(%(
      class Parent
        def a
          1
        end
      end

      module Mod(T)
        def a
          super
        end
      end

      class Child < Parent
        include Mod(Int32)
      end

      Child.new.a
      )).to_i.should eq(1)
  end

  it "does super in virtual type including module" do
    run(%(
      module Bar
        def bar
          123
        end
      end

      module Foo
        include Bar

        def bar
          super
        end
      end

      class Base
        include Foo
      end

      class Child < Base
      end

      (Base.new || Child.new).bar
      )).to_i.should eq(123)
  end

  it "doesn't invoke super twice in inherited generic types (#942)" do
    run(%(
      $a = 0

      abstract class Foo
      end

      class Bar(T) < Foo
        def initialize
            $a += 1
            super
        end
      end

      class Baz(T) < Bar(T)
      end

      Baz(Int8).new

      $a
      )).to_i.should eq(1)
  end
end
