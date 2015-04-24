require "../../spec_helper"

describe "Codegen: responds_to?" do
  it "codegens responds_to? true for simple type" do
    expect(run("1.responds_to?(:\"+\")").to_b).to be_true
  end

  it "codegens responds_to? false for simple type" do
    expect(run("1.responds_to?(:foo)").to_b).to be_false
  end

  it "codegens responds_to? with union gives true" do
    expect(run("(1 == 1 ? 1 : 'a').responds_to?(:\"+\")").to_b).to be_true
  end

  it "codegens responds_to? with union gives false" do
    expect(run("(1 == 1 ? 1 : 'a').responds_to?(:\"foo\")").to_b).to be_false
  end

  it "codegens responds_to? with nilable gives true" do
    expect(run("struct Nil; def foo; end; end; (1 == 1 ? nil : Reference.new).responds_to?(:foo)").to_b).to be_true
  end

  it "codegens responds_to? with nilable gives false becuase other type 1" do
    expect(run("(1 == 1 ? nil : Reference.new).responds_to?(:foo)").to_b).to be_false
  end

  it "codegens responds_to? with nilable gives false becuase other type 2" do
    expect(run("class Reference; def foo; end; end; (1 == 2 ? nil : Reference.new).responds_to?(:foo)").to_b).to be_true
  end

  it "codegends responds_to? with generic class (1)" do
    expect(run(%(
      class Foo(T)
        def foo
        end
      end

      Foo(Int32).new.responds_to?(:foo)
      )).to_b).to be_true
  end

  it "codegends responds_to? with generic class (2)" do
    expect(run(%(
      class Foo(T)
        def foo
        end
      end

      Foo(Int32).new.responds_to?(:bar)
      )).to_b).to be_false
  end
end
