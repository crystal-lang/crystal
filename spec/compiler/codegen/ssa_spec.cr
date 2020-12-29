require "../../spec_helper"

describe "Code gen: ssa" do
  it "codegens a redefined var" do
    run("
      a = 1.5
      a = 1
      a
      ").to_i.should eq(1)
  end

  it "codegens a redefined var inside method" do
    run("
      def foo
        a = 1.5
        a = 1
        a
      end

      foo
      ").to_i.should eq(1)
  end

  it "codegens a redefined var inside method with argument" do
    run("
      def foo(a)
        a = 1
        a
      end

      foo 1.5
      ").to_i.should eq(1)
  end

  it "codegens declaration of var inside then when false" do
    run("
      struct Nil
        def to_i!
          0
        end
      end

      if 1 == 2
        b = 2
      end
      b.to_i!
      ").to_i.should eq(0)
  end

  it "codegens declaration of var inside then when true" do
    run("
      struct Nil
        def to_i!
          0
        end
      end

      if 1 == 1
        b = 2
      end
      b.to_i!
      ").to_i.should eq(2)
  end

  it "codegens a var that is re-assigned in a block" do
    run(%(
      struct Char
        def to_i!
          10
        end
      end

      def foo
        yield
      end

      a = 1
      foo do
        a = 'a'
      end
      a.to_i!
      )).to_i.should eq(10)
  end

  it "codegens a var that is re-assigned in a block (1)" do
    run(%(
      struct Char
        def to_i!
          10
        end
      end

      a = 1
      while a.to_i! == 1
        a = 'a'
      end
      a.to_i!
      )).to_i.should eq(10)
  end

  it "codegens a var that is re-assigned in a block (2)" do
    run(%(
      struct Char
        def to_i!
          10
        end
      end

      a = 1
      while 1 == 2
        a = 'a'
      end
      a.to_i!
      )).to_i.should eq(1)
  end

  it "codegens a var that is declared in a block (1)" do
    run(%(
      struct Nil
        def to_i!
          0
        end
      end

      while 1 == 2
        a = 1
      end
      a.to_i!
      )).to_i.should eq(0)
  end

  it "codegens a var that is declared in a block (2)" do
    run(%(
      struct Nil
        def to_i!
          0
        end
      end

      b = 1
      while b == 1
        a = 1
        b = 2
      end
      a.to_i!
      )).to_i.should eq(1)
  end

  it "codegens ssa bug with if/else on var" do
    run(%(
      a = 1 || nil
      if a && false
        b = 2
      elsif a
        b = 3
      else
        b = 4
      end
      b
      )).to_i.should eq(3)
  end

  it "codegens ssa bug (1)" do
    run(%(
      struct Nil
        def to_i!
          0
        end
      end

      index = nil
      if index
        a = index
        1
      else
        if 1 == 1
          index = 1
        else
          1
        end
        a = index
        1
      end
      a.to_i!
      )).to_i.should eq(1)
  end

  it "codegens ssa bug (2)" do
    # This shows a bug where a block variable (coconio in this case)
    # wasn't reset to nil before each block iteration.
    run(%(
      struct Nil
        def to_i!
          0
        end
      end

      def foo
        i = 1
        while i <= 3
          yield i
          i &+= 1
        end
      end

      a = 0
      foo do |x|
        coconio = x if x == 1
        a &+= coconio.to_i!
      end
      a
      )).to_i.should eq(1)
  end
end
