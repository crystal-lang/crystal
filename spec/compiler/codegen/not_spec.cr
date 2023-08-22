require "../../spec_helper"

describe "Code gen: not" do
  it "codegens not number" do
    run("!1").to_b.should be_false
  end

  it "codegens not true" do
    run("!true").to_b.should be_false
  end

  it "codegens not false" do
    run("!false").to_b.should be_true
  end

  it "codegens not nil" do
    run("!nil").to_b.should be_true
  end

  it "codegens not nilable type (true)" do
    run(%(
      class Foo
      end

      a = 1 == 2 ? Foo.new : nil
      !a
      )).to_b.should be_true
  end

  it "codegens not nilable type (false)" do
    run(%(
      class Foo
      end

      a = 1 == 1 ? Foo.new : nil
      !a
      )).to_b.should be_false
  end

  it "codegens not pointer (true)" do
    run(%(
      !Pointer(Int32).new(0_u64)
      )).to_b.should be_true
  end

  it "codegens not pointer (false)" do
    run(%(
      !Pointer(Int32).new(1_u64)
      )).to_b.should be_false
  end

  it "doesn't crash" do
    run(%(
      a = 1
      !a.is_a?(String) && !a
      )).to_b.should be_false
  end

  it "codegens not with inlinable value (#6451)" do
    codegen(%(
      class Test
        def test
          false
        end
      end

      !Test.new.test
      nil))
  end
end
