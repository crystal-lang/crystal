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
        def to_i
          0
        end
      end

      if 1 == 2
        b = 2
      end
      b.to_i
      ").to_i.should eq(0)
  end

  it "codegens declaration of var inside then when true" do
    run("
      struct Nil
        def to_i
          0
        end
      end

      if 1 == 1
        b = 2
      end
      b.to_i
      ").to_i.should eq(2)
  end
end
