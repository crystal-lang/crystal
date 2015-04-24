require "../../spec_helper"

describe "Code gen: var" do
  it "codegens var" do
    expect(run("a = 1; 1.5; a").to_i).to eq(1)
  end

  it "codegens ivar assignment when not-nil type filter applies" do
    expect(run("
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
      ").to_i).to eq(2)
  end

  it "codegens bug with instance vars and ssa" do
    expect(run("
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
      ").to_i).to eq(-1)
  end

  it "codegens bug with var, while, if, break and ssa" do
    expect(run("
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
      ").to_i).to eq(2)
  end

  it "codegens bug with union of int, nil and string (1): assigning nil to union must fill all zeros" do
    expect(run(%(
      struct Nil
        def foo
          1
        end
      end

      class String
        def foo
          2
        end
      end

      x = 80
      if true
        x = nil
      else
        x = "a"
      end
      x.foo
      )).to_i).to eq(1)
  end

  it "codegens bug with union of int, nil and string (2): assigning nil to union must fill all zeros" do
    expect(run(%(
      struct Nil
        def foo
          1
        end
      end

      class String
        def foo
          2
        end
      end

      x = 443
      if true
        x = nil
      else
        x = "a"
      end
      x.foo
      )).to_i).to eq(1)
  end

  it "codegens assignment that can never be reached" do
    build(%(
      require "prelude"

      if 1 == 1 && (x = nil)
        z = x
      end
      ))
  end
end
