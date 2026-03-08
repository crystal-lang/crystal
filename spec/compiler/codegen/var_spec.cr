require "../../spec_helper"

describe "Code gen: var" do
  it "codegens var" do
    run("a = 1; 1.5; a").to_i.should eq(1)
  end

  it "codegens var with type declaration" do
    run("a = (b : Int32 = 1); a").to_i.should eq(1)
  end

  it "codegens ivar assignment when not-nil type filter applies" do
    run(<<-CRYSTAL).to_i.should eq(2)
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
      CRYSTAL
  end

  it "codegens bug with instance vars and ssa" do
    run(<<-CRYSTAL).to_i.should eq(-1)
      class Foo
        def initialize
          @angle = 0
        end

        def foo
          if 1 == 2
            @angle &+= 1
          else
            @angle &-= 1
          end
        end
      end

      f = Foo.new
      f.foo
      CRYSTAL
  end

  it "codegens bug with var, while, if, break and ssa" do
    run(<<-CRYSTAL).to_i.should eq(2)
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
      CRYSTAL
  end

  it "codegens bug with union of int, nil and string (1): assigning nil to union must fill all zeros" do
    run(<<-CRYSTAL).to_i.should eq(1)
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
      CRYSTAL
  end

  it "codegens bug with union of int, nil and string (2): assigning nil to union must fill all zeros" do
    run(<<-CRYSTAL).to_i.should eq(1)
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
      CRYSTAL
  end

  it "codegens assignment that can never be reached" do
    codegen(<<-CRYSTAL)
      if 1 == 1 && (x = nil)
        z = x
      end
      CRYSTAL
  end

  it "works with typeof with assignment (#828)" do
    run(<<-CRYSTAL).to_i.should eq(123)
      class String; def to_i!; 0; end; end

      a = 123
      typeof(a = "hello")
      a.to_i!
      CRYSTAL
  end

  it "assigns to underscore" do
    run(<<-CRYSTAL).to_i.should eq(2)
      _ = (b = 2)
      b
      CRYSTAL
  end
end
