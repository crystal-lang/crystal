require "../../spec_helper"

describe "Code gen: uninitialized" do
  it "codegens declare var and read it" do
    run("a = uninitialized Int32; a")
  end

  it "codegens declare var and changes it" do
    run("a = uninitialized Int32; while a != 10; a = 10; end; a").to_i.should eq(10)
  end

  it "codegens declare instance var" do
    run("
      class Foo
        def initialize
          @x = uninitialized Int32
        end

        def x
          @x
        end
      end

      Foo.new.x
      ").to_i.should eq(0)
  end

  it "codegens declare instance var with static array type" do
    run("
      class Foo
        def initialize
          @x = uninitialized Int32[4]
        end

        def x
          @x
        end
      end

      Foo.new.x
      nil
      ")
  end

  it "doesn't break on inherited declared var (#390)" do
    run(%(
      class Foo
        def initialize
          @x = 1
        end
      end

      class Bar < Foo
        def initialize
          @x = uninitialized Int32
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
      bar.x &+ bar.y
      )).to_i.should eq(3)
  end

  it "works inside while/begin/rescue (bug inside #759)" do
    run(%(
      require "prelude"

      a = 3
      while 1
        begin
          buf = uninitialized Int32
          buf + 1
          break if a == 3
        rescue
        end
      end
      a
      )).to_i.should eq(3)
  end

  it "works with uninitialized NoReturn (#3314)" do
    codegen(%(
      def foo
        x = uninitialized NoReturn
        if 1
          x = yield
        end
        x
      end

      def bar
        foo { return }
      end

      bar
      ), inject_primitives: false)
  end

  it "codegens value (#3641)" do
    run(%(
      x = y = uninitialized Int32
      x == y
      )).to_b.should be_true
  end
end
