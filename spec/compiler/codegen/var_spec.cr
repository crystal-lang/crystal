require "../../spec_helper"

describe "Code gen: var" do
  it "codegens var" do
    run("a = 1; 1.5; a").to_i.should eq(1)
  end

  it "codegens ivar assignment when not-nil type filter applies" do
    run("
      class Foo
        def foo
          if @a
            x = @a
          end
          @a = 2
        end
      end

      foo = Foo.new
      foo.foo
      ").to_i.should eq(2)
  end

  it "codegens bug with instance vars and ssa" do
    run("
      class Foo
        def initialize
          @angle = 0
        end

        def foo
          if 1 == 2
            @angle += 1
          else
            @angle -= 1
          end
        end
      end

      f = Foo.new
      f.foo
      ").to_i.should eq(-1)
  end

  it "codegens bug with var, while, if, break and ssa" do
    run("
      a = 1
      a = 2

      while 1 == 1
        if 1 == 2
          a = 3
        else
          break
        end
      end

      a
      ").to_i.should eq(2)
  end
end
