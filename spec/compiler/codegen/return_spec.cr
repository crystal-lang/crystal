require "../../spec_helper"

describe "Code gen: return" do
  it "codegens return" do
    run("def foo; return 1; end; foo").to_i.should eq(1)
  end

  it "codegens return followed by another expression" do
    run("def foo; return 1; 2; end; foo").to_i.should eq(1)
  end

  it "codegens return inside if" do
    run("def foo; if 1 == 1; return 1; end; 2; end; foo").to_i.should eq(1)
  end

  it "return from function with union type" do
    run("struct Char; def to_i!; 2; end; end; def foo; return 1 if 1 == 1; 'a'; end; foo.to_i!").to_i.should eq(1)
  end

  it "return union" do
    run("struct Char; def to_i!; 2; end; end; def foo; 1 == 2 ? return 1 : return 'a'; end; foo.to_i!").to_i.should eq(2)
  end

  it "return from function with nilable type" do
    run(%(require "prelude"; def foo; return Reference.new if 1 == 1; end; foo.nil?)).to_b.should be_false
  end

  it "return from function with nilable type 2" do
    run(%(require "prelude"; def foo; return Reference.new if 1 == 1; end; foo.nil?)).to_b.should be_false
  end

  it "returns empty from function" do
    run("
      struct Nil; def to_i!; 0; end; end
      def foo(x)
        return if x == 1
        1
      end

      foo(2).to_i!
    ").to_i.should eq(1)
  end

  it "codegens bug with return if true" do
    run(%(
      def bar
        return if true
        1
      end

      bar.is_a?(Nil)
      )).to_b.should be_true
  end

  it "codegens assign with if with two returns" do
    run(%(
      def test
        a = 1 ? return 2 : return 3
      end

      test
      )).to_i.should eq(2)
  end

  it "doesn't crash when method returns nil and can be inlined" do
    codegen(%(
      def foo : Nil
        1
      end

      foo
      ))
  end

  it "returns in var assignment (#3364)" do
    run(%(
      def bar
        a = nil || return 123
      end

      bar
      )).to_i.should eq(123)
  end

  it "forms a tuple from multiple return values" do
    run(%(
      def foo
        return 5, 3
      end

      v = foo
      v[0] &- v[1]
      )).to_i.should eq(2)
  end

  it "flattens splats inside multiple return values" do
    run(%(
      def foo
        return 1, *{3, 9}, 27
      end

      v = foo
      v[3] &- v[2]
      )).to_i.should eq(18)
  end
end
