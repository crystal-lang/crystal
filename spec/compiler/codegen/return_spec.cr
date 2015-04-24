require "../../spec_helper"

describe "Code gen: return" do
  it "codegens return" do
    expect(run("def foo; return 1; end; foo").to_i).to eq(1)
  end

  it "codegens return followed by another expression" do
    expect(run("def foo; return 1; 2; end; foo").to_i).to eq(1)
  end

  it "codegens return inside if" do
    expect(run("def foo; if 1 == 1; return 1; end; 2; end; foo").to_i).to eq(1)
  end

  it "return from function with union type" do
    expect(run("struct Char; def to_i; 2; end; end; def foo; return 1 if 1 == 1; 'a'; end; foo.to_i").to_i).to eq(1)
  end

  it "return union" do
    expect(run("struct Char; def to_i; 2; end; end; def foo; 1 == 2 ? return 1 : return 'a'; end; foo.to_i").to_i).to eq(2)
  end

  it "return from function with nilable type" do
    expect(run("require \"nil\"; require \"reference\"; def foo; return Reference.new if 1 == 1; end; foo.nil?").to_b).to be_false
  end

  it "return from function with nilable type 2" do
    expect(run("require \"nil\"; require \"reference\"; def foo; return Reference.new if 1 == 1; end; foo.nil?").to_b).to be_false
  end

  it "returns empty from function" do
    expect(run("
      struct Nil; def to_i; 0; end; end
      def foo(x)
        return if x == 1
        1
      end

      foo(2).to_i
    ").to_i).to eq(1)
  end
end
