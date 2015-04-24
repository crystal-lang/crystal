require "../../spec_helper"

describe "Type inference: yield with scope" do
  it "uses scope in global method" do
    expect(run("
      require \"prelude\"
      def foo; with 1 yield; end

      foo do
        succ
      end
    ").to_i).to eq(2)
  end

  it "uses scope in instance method" do
    expect(run("
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
    ").to_i).to eq(2)
  end

  it "it uses self for instance method" do
    expect(run("
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
    ").to_i).to eq(10)
  end

  it "it invokes global method inside block of yield scope" do
    expect(run("
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
    ").to_i).to eq(3)
  end

  it "generate right code when yielding struct as scope" do
    expect(run("
      struct Foo
        def bar; end
      end

      def foo
        with Foo.new yield
        1
      end

      foo { bar }
    ").to_i).to eq(1)
  end

  it "doesn't explode if specifying &block but never using it (#181)" do
    build(%(
      class A
        def a(&block)
          with self yield
        end
        def aa
        end
      end
      a = A.new
      a.a { aa }
      a.a { aa }
      ))
  end

  it "uses instance variable of enclosing scope" do
    expect(run(%(
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
            @x + 1
          end
        end
      end

      Bar.new.bar
      )).to_i).to eq(2)
  end

  it "uses method of enclosing scope" do
    expect(run(%(
      class Foo
        def foo
          with self yield
        end
      end

      class Bar
        def bar
          Foo.new.foo do
            baz + 1
          end
        end

        def baz
          1
        end
      end

      Bar.new.bar
      )).to_i).to eq(2)
  end

  it "uses method of with object" do
    expect(run(%(
      class Foo
        def initialize
          @x = 1
        end

        def foo
          with self yield
        end

        def coco
          @x + 1
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
      )).to_i).to eq(2)
  end
end
