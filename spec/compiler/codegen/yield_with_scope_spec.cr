require "../../spec_helper"

describe "Semantic: yield with scope" do
  it "uses scope in global method" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "prelude"
      def foo; with 1 yield; end

      foo do
        succ
      end
      CRYSTAL
  end

  it "uses scope in instance method" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "prelude"
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
      CRYSTAL
  end

  it "it uses self for instance method" do
    run(<<-CRYSTAL).to_i.should eq(10)
      require "prelude"
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
      CRYSTAL
  end

  it "it invokes global method inside block of yield scope" do
    run(<<-CRYSTAL).to_i.should eq(3)
      require "prelude"

      def foo
        with -1 yield
      end

      def plus_two(x)
        x + 2
      end

      foo do
        plus_two abs
      end
      CRYSTAL
  end

  it "generate right code when yielding struct as scope" do
    run(<<-CRYSTAL).to_i.should eq(1)
      struct Foo
        def bar; end
      end

      def foo
        with Foo.new yield
        1
      end

      foo { bar }
      CRYSTAL
  end

  it "doesn't explode if specifying &block but never using it (#181)" do
    codegen(<<-CRYSTAL)
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
      CRYSTAL
  end

  it "uses instance variable of enclosing scope" do
    run(<<-CRYSTAL).to_i.should eq(2)
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
      CRYSTAL
  end

  it "uses method of enclosing scope" do
    run(<<-CRYSTAL).to_i.should eq(2)
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
      CRYSTAL
  end

  it "uses method of with object" do
    run(<<-CRYSTAL).to_i.should eq(2)
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
      CRYSTAL
  end

  it "yields with dispatch (#2171) (1)" do
    run(<<-CRYSTAL).to_i.should eq(10)
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
      CRYSTAL
  end

  it "yields virtual type (#2171) (2)" do
    run(<<-CRYSTAL).to_i.should eq(2)
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
      CRYSTAL
  end
end
