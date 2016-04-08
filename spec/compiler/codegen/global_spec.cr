require "../../spec_helper"

describe "Code gen: global" do
  it "codegens global" do
    run("$foo = 1; def foo; $foo = 2; end; foo; $foo").to_i.should eq(2)
  end

  it "codegens global with union" do
    run("$foo = 1; def foo; $foo = 2.5_f32; end; foo; $foo.to_f").to_f64.should eq(2.5)
  end

  it "codegens global when not initialized" do
    run(%(
      struct Nil; def to_i; 0; end; end
      $foo : Int32?
      $foo.to_i
      )).to_i.should eq(0)
  end

  it "codegens global when not initialized" do
    run(%(
      struct Nil; def to_i; 0; end; end

      def foo
        $foo = 2 if 1 == 2
      end

      foo

      $foo.to_i
      )).to_i.should eq(0)
  end
end
