require "../../spec_helper"

describe "Code gen: declare var" do
  it "codegens declare var and read it" do
    # Using :: is unsafe and returns uninitialized memory
    run("a :: Int32; a")
  end

  it "codegens declare var and changes it" do
    expect(run("a :: Int32; while a != 10; a = 10; end; a").to_i).to eq(10)
  end

  it "codegens declare instance var" do
    expect(run("
      class Foo
        def initialize
          @x :: Int32
        end

        def x
          @x
        end
      end

      Foo.new.x
      ").to_i).to eq(0)
  end

  it "codegens declare instance var with static array type" do
    run("
      class Foo
        def initialize
          @x :: Int32[4]
        end

        def x
          @x
        end
      end

      Foo.new.x
      nil
      ")
  end

  it "codegens initialize instance var" do
    expect(run("
      class Foo
        @x = 1

        def x
          @x
        end
      end

      Foo.new.x
      ").to_i).to eq(1)
  end

  it "codegens initialize instance var of superclass" do
    expect(run("
      class Foo
        @x = 1

        def x
          @x
        end
      end

      class Bar < Foo
      end

      Bar.new.x
      ").to_i).to eq(1)
  end

  it "codegens initialize instance var with var declaration" do
    expect(run("
      class Foo
        @x = begin
          a = 1
          a
        end

        def x
          @x
        end
      end

      Foo.new.x
      ").to_i).to eq(1)
  end

  it "doesn't break on inherited declared var (#390)" do
    expect(run(%(
      class Foo
        def initialize
          # @x :: Int32
          @x = 1
        end
      end

      class Bar < Foo
        def initialize
          @x :: Int32
          @x = 1
          @y = 2
        end

        def x
          @x
        end

        def y
          @y
        end
      end

      bar = Bar.new
      bar.x + bar.y
      )).to_i).to eq(3)
  end
end
