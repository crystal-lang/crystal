require "../../spec_helper"

describe "Code gen: method_missing" do
  it "does method_missing macro without args" do
    run("
      class Foo
        def foo_something
          1
        end

        macro method_missing(name, args, block)
          {{name.id}}_something
        end
      end

      Foo.new.foo
      ").to_i.should eq(1)
  end

  it "does method_missing macro with args" do
    run(%(
      class Foo
        macro method_missing(name, args, block)
          {{args.join(" + ").id}}
        end
      end

      Foo.new.foo(1, 2, 3)
      )).to_i.should eq(6)
  end

  it "does method_missing macro with block" do
    run(%(
      class Foo
        def foo_something
          yield 1
          yield 2
          yield 3
        end

        macro method_missing(name, args, block)
          {{name.id}}_something {{block}}
        end
      end

      a = 0
      Foo.new.foo do |x|
        a += x
      end
      a
      )).to_i.should eq(6)
  end

  it "does method_missing macro with block but not using it" do
    run(%(
      class Foo
        def foo_something
          1 + 2
        end

        macro method_missing(name, args, block)
          {{name.id}}_something {{block}}
        end
      end

      Foo.new.foo
      )).to_i.should eq(3)
  end

  it "does method_missing macro with virtual type (1)" do
    run(%(
      class Foo
        macro method_missing(name, args, block)
          "{{@class_name.id}}{{name.id}}"
        end
      end

      class Bar < Foo
      end

      foo = Foo.new || Bar.new
      foo.coco
      )).to_string.should eq("Foococo")
  end

  it "does method_missing macro with virtual type (2)" do
    run(%(
      class Foo
        macro method_missing(name, args, block)
          "{{@class_name.id}}{{name.id}}"
        end
      end

      class Bar < Foo
      end

      foo = Bar.new || Foo.new
      foo.coco
      )).to_string.should eq("Barcoco")
  end

  it "does method_missing macro with virtual type (3)" do
    run(%(
      class Foo
        def lala
          1
        end

        macro method_missing(name, args, block)
          2
        end
      end

      class Bar < Foo
      end

      foo = Bar.new || Foo.new
      foo.lala
      )).to_i.should eq(1)
  end

  it "does method_missing macro with virtual type (4)" do
    run(%(
      class Foo
        macro method_missing(name, args, block)
          1
        end
      end

      class Bar < Foo
        macro method_missing(name, args, block)
          2
        end
      end

      foo = Bar.new || Foo.new
      foo.lala
      )).to_i.should eq(2)
  end

  it "does method_missing macro with virtual type (5)" do
    run(%(
      class Foo
        macro method_missing(name, args, block)
          1
        end
      end

      class Bar < Foo
        macro method_missing(name, args, block)
          2
        end
      end

      class Baz < Bar
        macro method_missing(name, args, block)
          3
        end
      end

      foo = Baz.new || Bar.new || Foo.new
      foo.lala
      )).to_i.should eq(3)
  end

  it "does method_missing macro with virtual type (6)" do
    run(%(
      abstract class Foo
      end

      class Bar < Foo
        macro method_missing(name, args, block)
          2
        end
      end

      class Baz < Bar
        def lala
          3
        end
      end

      foo = Bar.new || Baz.new
      foo.lala
      )).to_i.should eq(2)
  end

  it "does method_missing macro with virtual type (7)" do
    run(%(
      abstract class Foo
      end

      class Bar < Foo
        macro method_missing(name, args, block)
          2
        end
      end

      class Baz < Bar
        def lala
          3
        end
      end

      foo = Baz.new || Bar.new
      foo.lala
      )).to_i.should eq(3)
  end

  it "does method_missing macro with virtual type (8)" do
    run(%(
      class Foo
        macro method_missing(name, args, block)
          {{@class_name}}
        end
      end

      class Bar < Foo
      end

      foo = Foo.new
      foo.coco

      bar = Bar.new
      bar.coco
      )).to_string.should eq("Bar")
  end

  it "does method_missing macro with module involved" do
    run("
      module Moo
        def lala
          1
        end
      end

      class Foo
        include Moo

        macro method_missing(name, args, block)
          2
        end
      end

      Foo.new.lala
      ").to_i.should eq(1)
  end

  it "does method_missing macro with top level method involved" do
    run("
      def lala
        1
      end

      class Foo
        macro method_missing(name, args, block)
          2
        end

        def bar
          lala
        end
      end

      foo = Foo.new
      foo.bar
      ").to_i.should eq(1)
  end

  it "does method_missing macro with included module" do
    run("
      module Moo
        macro method_missing(name, args, block)
          {{@class_name}}
        end
      end

      class Foo
        include Moo
      end

      Foo.new.coco
      ").to_string.should eq("Foo")
  end

  it "does method_missing with assignment (bug)" do
    run(%(
      class Foo
        macro method_missing(name, args, block)
          x = {{args[0]}}
          x
        end
      end

      foo = Foo.new
      foo.bar(1)
      )).to_i.should eq(1)
  end

  it "does method_missing with assignment (2) (bug)" do
    run(%(
      struct Nil
        def to_i
          0
        end
      end

      class Foo
        macro method_missing(name, args, block)
          @x = {{args[0]}}
          @x
        end
      end

      foo = Foo.new
      foo.bar(1).to_i
      )).to_i.should eq(1)
  end
end
