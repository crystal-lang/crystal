#!/usr/bin/env bin/crystal --run
require "../../spec_helper"

describe "Code gen: macro" do
  it "expands macro" do
    run("macro foo; 1 + 2; end; foo").to_i.should eq(3)
  end

  it "expands macro with arguments" do
    run(%(
      macro foo(n)
        {{n}} + 2
      end

      foo(1)
      )).to_i.should eq(3)
  end

  it "expands macro that invokes another macro" do
    run(%(
      macro foo
        def x
          1 + 2
        end
      end

      macro bar
        foo
      end

      bar
      x
      )).to_i.should eq(3)
  end

  it "expands macro defined in class" do
    run(%(
      class Foo
        macro foo
          def bar
            1
          end
        end

        foo
      end

      foo = Foo.new
      foo.bar
    )).to_i.should eq(1)
  end

  it "expands macro defined in base class" do
    run(%(
      class Object
        macro foo
          def bar
            1
          end
        end
      end

      class Foo
        foo
      end

      foo = Foo.new
      foo.bar
    )).to_i.should eq(1)
  end

  it "expands inline macro" do
    run(%(
      a = {{ 1 }}
      a
      )).to_i.should eq(1)
  end

  it "expands inline macro for" do
    run(%(
      a = 0
      {% for i in [1, 2, 3] %}
        a += {{i}}
      {% end %}
      a
      )).to_i.should eq(6)
  end

  it "expands inline macro if (true)" do
    run(%(
      a = 0
      {% if 1 == 1 %}
        a += 1
      {% end %}
      a
      )).to_i.should eq(1)
  end

  it "expands inline macro if (false)" do
    run(%(
      a = 0
      {% if 1 == 2 %}
        a += 1
      {% end %}
      a
      )).to_i.should eq(0)
  end

  it "finds macro in class" do
    run(%(
      class Foo
        macro foo
          1 + 2
        end

        def bar
          foo
        end
      end

      Foo.new.bar
      )).to_i.should eq(3)
  end

  it "expands def macro" do
    run(%(
      def bar_baz
        1
      end

      def foo : Int32
        bar_{{ "baz" }}
      end

      foo
      )).to_i.should eq(1)
  end

  it "expands def macro with var" do
    run(%(
      def foo : Int32
        a = {{ 1 }}
      end

      foo
      )).to_i.should eq(1)
  end

  it "expands def macro with @instance_vars" do
    run(%(
      class Foo
        def initialize(@x)
        end

        def to_s : String
          {{ @instance_vars.first.stringify }}
        end
      end

      foo = Foo.new(1)
      foo.to_s
      )).to_string.should eq("@x")
  end

  it "expands def macro with @instance_vars with subclass" do
    run(%(
      class Reference
        def to_s : String
          {{ @instance_vars.last.stringify }}
        end
      end

      class Foo
        def initialize(@x)
        end
      end

      class Bar < Foo
        def initialize(@x, @y)
        end
      end

      Bar.new(1, 2).to_s
      )).to_string.should eq("@y")
  end

  it "expands def macro with @instance_vars with hierarchy" do
    run(%(
      class Reference
        def to_s : String
          {{ @instance_vars.last.stringify }}
        end
      end

      class Foo
        def initialize(@x)
        end
      end

      class Bar < Foo
        def initialize(@x, @y)
        end
      end

      (Bar.new(1, 2) || Foo.new(1)).to_s
      )).to_string.should eq("@y")
  end

  it "expands def macro with @name" do
    run(%(
      class Foo
        def initialize(@x)
        end

        def to_s : String
          {{ @name.stringify }}
        end
      end

      foo = Foo.new(1)
      foo.to_s
      )).to_string.should eq("Foo")
  end

  it "expands macro and resolves type correctly" do
    run(%(
      class Foo
        def foo : Int32
          1
        end
      end

      class Bar < Foo
        Int32 = 2
      end

      Bar.new.foo
      )).to_i.should eq(1)
  end

  it "allows overriding macro definition when redefining base class" do
    run(%(
      class Foo
        def inspect : String
          {{ @name.stringify }}
        end
      end

      class Bar < Foo
      end

      class Foo
        def inspect
          "OH NO"
        end
      end

      Bar.new.inspect
      )).to_string.should eq("OH NO")
  end
end
