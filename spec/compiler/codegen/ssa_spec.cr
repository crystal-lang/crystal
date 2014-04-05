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
end
