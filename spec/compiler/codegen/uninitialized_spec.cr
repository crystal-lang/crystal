require "../../spec_helper"

describe "Code gen: uninitialized" do
  it "codegens declare var and read it" do
    run("a = uninitialized Int32; a")
  end

  it "codegens declare var and changes it" do
    run("a = uninitialized Int32; while a != 10; a = 10; end; a").to_i.should eq(10)
  end

  it "codegens declare instance var" do
    run(<<-CRYSTAL).to_i.should eq(0)
      class Foo
        def initialize
          @x = uninitialized Int32
        end

        def x
          @x
        end
      end

      Foo.new.x
      CRYSTAL
  end

  it "codegens declare instance var with static array type" do
    run(<<-CRYSTAL)
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
      CRYSTAL
  end

  it "doesn't break on inherited declared var (#390)" do
    run(<<-CRYSTAL).to_i.should eq(3)
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
      CRYSTAL
  end

  it "works inside while/begin/rescue (bug inside #759)" do
    run(<<-CRYSTAL).to_i.should eq(3)
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
      CRYSTAL
  end

  it "works with uninitialized NoReturn (#3314)" do
    codegen(<<-CRYSTAL, inject_primitives: false)
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
      CRYSTAL
  end

  it "codegens value (#3641)" do
    run(<<-CRYSTAL).to_b.should be_true
      x = y = uninitialized Int32
      x == y
      CRYSTAL
  end
end
