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
    run(<<-CRYSTAL).to_b.should be_true
      class Foo
      end

      a = 1 == 2 ? Foo.new : nil
      !a
      CRYSTAL
  end

  it "codegens not nilable type (false)" do
    run(<<-CRYSTAL).to_b.should be_false
      class Foo
      end

      a = 1 == 1 ? Foo.new : nil
      !a
      CRYSTAL
  end

  it "codegens not pointer (true)" do
    run(<<-CRYSTAL).to_b.should be_true
      !Pointer(Int32).new(0_u64)
      CRYSTAL
  end

  it "codegens not pointer (false)" do
    run(<<-CRYSTAL).to_b.should be_false
      !Pointer(Int32).new(1_u64)
      CRYSTAL
  end

  it "doesn't crash" do
    run(<<-CRYSTAL).to_b.should be_false
      a = 1
      !a.is_a?(String) && !a
      CRYSTAL
  end

  it "codegens not with inlinable value (#6451)" do
    codegen(<<-CRYSTAL)
      class Test
        def test
          false
        end
      end

      !Test.new.test
      nil
      CRYSTAL
  end
end
