require "../../spec_helper"

describe "Semantic: yield with scope" do
  it "uses scope in global method" do
    run("
      require \"prelude\"
      def foo; with 1 yield; end

      foo do
        succ
      end
    ").to_i.should eq(2)
  end

  it "uses scope in instance method" do
    run("
      require \"prelude\"
      def foo; with 1 yield; end

      class Foo
        def test
          foo do
            succ
          end
        end

        def succ
          10
        end
      end

      Foo.new.test
    ").to_i.should eq(2)
  end

  it "it uses self for instance method" do
    run("
      require \"prelude\"
      def foo; with 1 yield; end

      class Foo
        def test
          foo do
            self.succ
          end
        end

        def succ
          10
        end
      end

      Foo.new.test
    ").to_i.should eq(10)
  end

  it "it invokes global method inside block of yield scope" do
    run("
      require \"prelude\"

      def foo
        with -1 yield
      end

      def plus_two(x)
        x + 2
      end

      foo do
        plus_two abs
      end
    ").to_i.should eq(3)
  end

  it "generate right code when yielding struct as scope" do
    run("
      struct Foo
        def bar; end
      end

      def foo
        with Foo.new yield
        1
      end

      foo { bar }
    ").to_i.should eq(1)
  end

  it "doesn't explode if specifying &block but never using it (#181)" do
    codegen(%(
      class Foo
        def a(&block)
          with self yield
        end
        def aa
        end
      end
      a = Foo.new
      a.a { aa }
      a.a { aa }
      ))
  end

  it "uses instance variable of enclosing scope" do
    run(%(
      class Foo
        def foo
          with self yield
        end
      end

      class Bar
        def initialize
          @x = 1
        end

        def bar
          Foo.new.foo do
            @x &+ 1
          end
        end
      end

      Bar.new.bar
      )).to_i.should eq(2)
  end

  it "uses method of enclosing scope" do
    run(%(
      class Foo
        def foo
          with self yield
        end
      end

      class Bar
        def bar
          Foo.new.foo do
            baz &+ 1
          end
        end

        def baz
          1
        end
      end

      Bar.new.bar
      )).to_i.should eq(2)
  end

  it "uses method of with object" do
    run(%(
      class Foo
        def initialize
          @x = 1
        end

        def foo
          with self yield
        end

        def coco
          @x &+ 1
        end
      end

      class Bar
        def bar
          Foo.new.foo do
            coco
          end
        end
      end

      Bar.new.bar
      )).to_i.should eq(2)
  end

  it "yields with dispatch (#2171) (1)" do
    run(%(
      class Foo
        def method(x : Int32)
          10
        end

        def method(x : Float64)
          20
        end
      end

      def foo
        with Foo.new yield
      end

      foo do
        method(1 || 1.5)
      end
      )).to_i.should eq(10)
  end

  it "yields virtual type (#2171) (2)" do
    run(%(
      class Foo
        def method
          1
        end
      end

      class Bar < Foo
        def method
          2
        end
      end

      def foo
        with (Bar.new || Foo.new) yield
      end

      foo { method }
      )).to_i.should eq(2)
  end
end
